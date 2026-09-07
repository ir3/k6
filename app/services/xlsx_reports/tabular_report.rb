# frozen_string_literal: true

module XlsxReports
  # 「見出し+明細テーブル(+合計行)」型の帳票(請求書・受領書・出荷伝票など)の共通レイアウト。
  # サブクラスは #columns を実装し、#build_item_table を呼んで明細部分を組み立てる。
  class TabularReport < BaseReport
    Column = Struct.new(:key, :label, :width, :halign, :number_format, :total, keyword_init: true)

    private

    # 例: [Column.new(key: :name, label: "品名・仕様", width: 30, halign: :left)]
    # total: true を付けた列だけ、合計行で上下辺が二重罫線になる。
    def columns
      raise NotImplementedError, "#{self.class} must define #columns"
    end

    # 明細テーブル(ヘッダー行+明細行+任意で合計行)をsheetに追加する。
    # items は columns の key をキーに持つHashの配列、total は同じ形のHash(任意)。
    def build_item_table(sheet, items:, total: nil)
      header_style = style(sheet, border: :thin, bold: true, halign: :center, valign: :center, fill: "FFC0C0C0")
      sheet.add_row(columns.map(&:label), style: Array.new(columns.size, header_style))

      items.each do |item|
        row_styles = columns.map { |c| style(sheet, border: :thin, halign: c.halign, valign: :center, number_format: c.number_format) }
        sheet.add_row(columns.map { |c| item[c.key] }, style: row_styles)
      end

      return unless total

      total_styles = columns.map do |c|
        edge = c.total ? :double : :thin
        style(sheet, border: :thin, top: edge, bottom: edge, halign: c.halign, valign: :center, number_format: c.number_format)
      end
      sheet.add_row(columns.map { |c| c.total ? total[c.key] : nil }, style: total_styles)
    end
  end
end
