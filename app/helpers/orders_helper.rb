# frozen_string_literal: true

module OrdersHelper
  # orderup.asp の取引先選択と同じ並び（縦=段、横=行）。「全」は絞り込みなし（全件）。
  # ASP にあった「他」は「全」と同じ動作（空文字）だったので省略している。
  KANA_ROWS = [
    %w[あ か さ た な は ま や ら わ ん],
    %w[い き し ち に ひ み 全 り],
    %w[う く す つ ぬ ふ む ゆ る],
    %w[え け せ て ね へ め れ],
    %w[お こ そ と の ほ も よ ろ を]
  ].freeze

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
