# frozen_string_literal: true

module OrdersHelper
  # 取引先選択の50音ボタン。あいうえお順に並べ、KANA_PER_ROW 個ごとに改行する（kana_rows 参照）。
  # 「全」は絞り込みなし（全件）。orderup.asp にあった「他」は「全」と同じ動作（空文字）だったので省略している。
  KANA_LIST = %w[
    あ い う え お か き く け こ さ し す せ そ
    た ち つ て と な に ぬ ね の は ひ ふ へ ほ
    ま み む め も や ゆ よ ら り る れ ろ わ を ん
    全
  ].freeze
  KANA_PER_ROW = 15

  # 50音ボタンの行分け。KANA_PER_ROW 個ずつ改行し、端数の最後の短い行は直前の行に続けて行数を抑える
  # （47個なら 15・15・17 の3行）。
  def kana_rows
    rows = KANA_LIST.each_slice(KANA_PER_ROW).to_a
    rows[-2].concat(rows.pop) if rows.size > 1
    rows
  end

  # 取引先の会社名（会社名が無い個人は氏名）
  def adlist_company_name(adlist)
    adlist&.company.presence || adlist&.name
  end

  # 取引先の部署名（部署名2があれば続けて表示。orderup.asp と同じ）
  def adlist_section_name(adlist)
    [ adlist&.section, adlist&.section2 ].compact_blank.join(" ")
  end

  # 船籍の選択肢（船籍マスタの並び。論理削除済みは除く）。
  # 現在値がマスタに無い（表記ゆれ・削除済み）場合も、保存し直して別の値に変わらないよう先頭に残す。
  def country_options(current)
    countries = Registry.where(deleted_at: nil).order(Arel.sql("CAST(countryid AS INTEGER)")).pluck(:country)
    countries.unshift(current) if current.present? && countries.exclude?(current)
    countries
  end
end
