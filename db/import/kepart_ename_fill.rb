# frozen_string_literal: true

# Ｂ部品（keparts）の英文名称が和文名称と同じになっているものを、元のＡ部品（parts）の英文名称で埋める。
#
# Ａ部品から作ったＢ部品は、部品コードの末尾に「~」が付く（例: Ａ部品 977120500 → Ｂ部品 977120500~）。
# 旧システムは、Ｂ部品の登録時にＡ部品の和文名称・英文名称をコピーしていたが、のちの登録や編集で
# 英文名称が和文名称と同じになった行がある（2026-11-12 時点で、「~」付き 795 件のうち 761 件）。
# その中で、元のＡ部品に別の英文名称がある行（579 件前後）だけを、ここで直す。
#
# 安全のための決まり:
# - 直すのは、部品コードが「~」で終わり、英文名称が和文名称と同じ（前後の空白は無視）のＢ部品だけ。
#   「~」の無いＢ部品は、Ａ部品と同じコードでも別の部品のことがあるので触らない
# - 別の英文名称が入っている行は触らない
# - 元のＡ部品（「~」を除いた部品コード）の英文名称が1通りで、アルファベットを含み、
#   Ｂ部品の英文名称と違うときだけ直す（カナだけ・数字だけのものは、英文名称とは言えないので写さない）
# - 更新日（updated_at）は変えない。英文名称だけを更新する
# - DRY_RUN=1 を付けると、何も変えずに、直す行を表示するだけにする
# - 直した行は、実行のたびに表示する（既定は先頭 30 件。VERBOSE=1 で全件）
#
# 注意: Access から ke部品 を取り込み直す（import_keparts.rb）と、英文名称は Access の値に戻る。
# 取り込み直したときは、このスクリプトも実行し直すこと。
module KepartEnameFill
  LIST_LIMIT = 30
  # Ａ部品から作ったＢ部品の、部品コードの末尾
  SUFFIX = "~"

  module_function

  # 直す行を返す。[{ id:, pcode:, jname:, old:, new: }, ...]
  def targets
    # Ａ部品の部品コードごとの英文名称。アルファベットを含むものだけを数え、食い違うものが複数あるコードは対象外にする
    candidates = Hash.new { |hash, code| hash[code] = [] }
    Part.where.not(pcode: [ nil, "" ]).pluck(:pcode, :ename).each do |code, ename|
      name = ename.to_s.strip
      candidates[code] << name if name.match?(/[A-Za-z]/)
    end
    unique_names = candidates.transform_values(&:uniq).select { |_, names| names.size == 1 }.transform_values(&:first)

    Kepart.where("pcode LIKE ?", "%#{SUFFIX}").order(:id).pluck(:id, :pcode, :jname, :ename).filter_map do |id, code, jname, ename|
      old = ename.to_s.strip
      next if old.empty? || old != jname.to_s.strip

      new_name = unique_names[code.delete_suffix(SUFFIX)]
      next if new_name.nil? || new_name == old

      { id: id, pcode: code, jname: jname.to_s.strip, old: old, new: new_name }
    end
  end

  # 英文名称を埋める。直した（DRY_RUN のときは直すはずの）行を返す
  def call(dry_run: false, verbose: false, io: $stdout)
    rows = targets
    if rows.empty?
      io.puts "keparts: 英文名称を直す行はありません（0 件）"
      return { rows: [], updated: 0 }
    end

    shown = verbose ? rows : rows.first(LIST_LIMIT)
    shown.each { |row| io.puts "  id=#{row[:id]} 部品=#{row[:pcode]} 英文名称 #{row[:old]} → #{row[:new]}" }
    io.puts "  …ほか #{rows.size - shown.size} 件（VERBOSE=1 で全件を表示）" if rows.size > shown.size

    if dry_run
      io.puts "keparts: DRY_RUN のため、#{rows.size} 件は変更しません"
      return { rows: rows, updated: 0 }
    end

    updated = 0
    Kepart.transaction do
      rows.each do |row|
        # update_all は、更新日を変えず、検証も通さない（英文名称だけを入れ替える）
        updated += Kepart.where(id: row[:id]).update_all(ename: row[:new])
      end
    end
    io.puts "keparts: 英文名称を、元のＡ部品の英文名称に #{updated} 件直しました"
    { rows: rows, updated: updated }
  end
end
