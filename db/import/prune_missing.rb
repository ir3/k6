# frozen_string_literal: true

# Access から取り込む在庫台帳（stocks / stockbs）で、Access に無くなった行を、k6 側からも取り除く。
#
# 取り込み（upsert）は、ID で行を追加・更新するだけで、削除は伝わらない。
# 本番の旧システムでは、台帳の行を消すことがある（旧 hzaikodel.asp が ZID を指定して行を削除する）。
# そのまま取り込み直すと、消えたはずの行が k6 に残り、在庫数が食い違う（2026-11-11 に A部品で10行、B部品で2行あった）。
# 本番へは Mac の DB を丸ごとコピーするので、取り込みのあと、Access と同じ行にそろえる必要がある。
#
# 安全のための決まり:
# - 消すのは「Access の最大ID以下で、Access に無い行」だけ。k6 で後から足した行（IDが Access の最大より大きい行）は消さない
# - 消す行数が max_delete（既定 50）を超えたら、何も消さずに止まる（Access の読み込みの失敗や、別のファイルを
#   取り違えたときに、大量に消さないため）。承知の上なら、MAX_DELETE=件数 を付けて実行する
# - Access から行が1行も読めなかったときは、何も消さない
# - DRY_RUN=1 を付けると、何も変えずに、消す行（と追加される行数）を表示するだけにする
# - 消した行は、実行のたびに全部表示する（あとから、どの行が消えたか分かるように）
module ImportPrune
  DEFAULT_MAX_DELETE = 50
  LIST_LIMIT = 50

  # 消す行が多すぎるときに出す。何も消していない
  class TooMany < StandardError; end

  module_function

  # Access に無い行の ID（Access の最大ID以下のものだけ）
  # model: ActiveRecord のモデル、access_ids: Access にある行の ID
  def stale_ids(model, access_ids)
    access = access_ids.to_set
    return [] if access.empty?

    limit = access.max
    model.unscoped.pluck(:id).select { |id| id <= limit && !access.include?(id) }.sort
  end

  # Access に無い行を削除する。消した（DRY_RUN のときは消すはずの）行の ID を返す
  # 戻り値: { ids: [...], deleted: 件数 }
  def call(model, access_ids, label:, max_delete: DEFAULT_MAX_DELETE, dry_run: false, io: $stdout)
    if access_ids.to_a.empty?
      io.puts "#{label}: Access から行が1行も読めなかったので、何も削除しません"
      return { ids: [], deleted: 0 }
    end

    ids = stale_ids(model, access_ids)
    if ids.empty?
      io.puts "#{label}: Access に無い行はありません（削除 0 件）"
      return { ids: [], deleted: 0 }
    end

    if ids.size > max_delete
      show(model, ids, io)
      raise TooMany, "#{label}: Access に無い行が #{ids.size} 件あり、上限 #{max_delete} 件を超えるので、何も削除しません。" \
                     "取り違えでなければ、MAX_DELETE=#{ids.size} を付けて実行し直してください"
    end

    show(model, ids, io)
    if dry_run
      io.puts "#{label}: DRY_RUN のため、#{ids.size} 件は削除しません"
      return { ids: ids, deleted: 0 }
    end

    deleted = ids.each_slice(500).sum { |slice| model.unscoped.where(id: slice).delete_all }
    io.puts "#{label}: Access に無い行を #{deleted} 件削除しました"
    { ids: ids, deleted: deleted }
  end

  # 消す行（消した行）を表示する
  def show(model, ids, io)
    rows = model.unscoped.where(id: ids.first(LIST_LIMIT)).order(:id)
    rows.each do |row|
      io.puts "  対象 id=#{row.id} 部品=#{row.partno} 数量=#{row.num} 取引=#{row.mno} 日付=#{row.indate} 備考=#{row.memo.to_s.strip}"
    end
    io.puts "  …ほか #{ids.size - LIST_LIMIT} 件" if ids.size > LIST_LIMIT
  end
end
