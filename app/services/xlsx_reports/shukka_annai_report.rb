# frozen_string_literal: true

module XlsxReports
  # 出荷案内書(syukka.xls / asp/A4pshuka.asp相当)。
  # 請求書(SeikyuReport)と同じ宛先・表題・船名などの見出しで、表が違う。
  # - 表の列は「No.」「品番」「品名・仕様」「数量」「単位」「摘　要」(単価・金額の列は無く、摘要は手書き用の空欄)
  # - 小計・累計・合計・取引銀行は出さない
  # 表題は「出　荷　案　内　書」、2ページ目以降の見出しは「出荷案内書」。ページの分け方(1ページ目21件、
  # 次紙26件)は請求書と同じ。
  # 出荷案内書を出すと取引管理(kubun=4)に日付が残り、請求書・納品書の出荷日になる。
  class ShukkaAnnaiReport < SeikyuReport
    def filename
      "shukka_annai_#{@order.mno}.xlsx"
    end

    def cover_title
      "出　荷　案　内　書"
    end

    def continuation_title
      "出荷案内書"
    end

    private

    # 1ページ目の見出しか、2ページ目以降の見出しか(表の組み立てで使う)
    def build_cover_header(sheet)
      @cover_page = true
      super
    end

    def build_continuation_header(sheet, page_no)
      @cover_page = false
      super
    end

    # 列幅は旧様式(syukka.xls)の列幅。摘要はF:Gの2列分
    def columns
      [
        Column.new(key: :no, width: 5),
        Column.new(key: :partno, width: 15),
        Column.new(key: :name, width: 36),
        Column.new(key: :qty, width: 7),
        Column.new(key: :unit, width: 6),
        Column.new(key: :remark1, width: 11),
        Column.new(key: :remark2, width: 14)
      ]
    end

    # 1明細=2行(1行目:ItemNo/備考/販売単位、2行目:品番/品名/数量/単位名)。摘要(F:G)は空欄。
    def build_two_row_items(sheet, items)
      header_style = style(sheet, border: :thin, bold: true, halign: :center, valign: :center, fill: "FFC0C0C0")
      (@table_header_rows ||= []) << (sheet.rows.size + 1)
      sheet.add_row([ "No.", "品番", "品名・仕様", "数量", "単位", "摘　要", nil ], style: Array.new(7) { header_style })
      set_last_row_height(sheet, 14)
      merge_remark(sheet)

      rows = table_items(items)
      rows.each_with_index do |item, idx|
        item ||= {}
        last = idx == rows.size - 1
        row1_default = style(sheet, top: :thin, left: :thin, right: :thin)
        row2_default = style(sheet, bottom: :thin, left: :thin, right: :thin)
        unit_halign = SalesUnit.numeric?(item[:sel_unit]) ? :left : :right
        remark1, remark2 = remark_styles(sheet, :top, last)
        remark_label = remark_text(idx)

        sheet.add_row(
          [ item[:no], item[:itemno], item[:info], nil, item[:sel_unit], remark_label, nil ],
          style: [ row1_default, row1_default, row1_default, row1_default,
                   style(sheet, top: :thin, left: :thin, right: :thin, halign: unit_halign),
                   style(sheet, **remark1, halign: :center), style(sheet, **remark2) ]
        )
        set_last_row_height(sheet, 14)
        merge_remark(sheet)
        remark1, remark2 = remark_styles(sheet, :bottom, last)
        sheet.add_row(
          [ nil, item[:partno], item[:name], item[:qty], item[:unit_name], nil, nil ],
          style: [
            row2_default, row2_default, row2_default,
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right),
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right),
            style(sheet, **remark1), style(sheet, **remark2)
          ]
        )
        set_last_row_height(sheet, 14)
        merge_remark(sheet)
      end
    end

    # 表に出す明細。出荷案内書は明細の件数分だけ(物品受領書が、受領印の枠のために空き行を足す)
    def table_items(items)
      items
    end

    # 摘要(F:G)の外枠。F(左)・G(右)のセルごとの罫線(style引数のHash)を返す。出荷案内書は明細の2行ごとに囲む
    def remark_styles(_sheet, position, _last)
      if position == :top
        [ { top: :thin, left: :thin }, { top: :thin, right: :thin } ]
      else
        [ { bottom: :thin, left: :thin }, { bottom: :thin, right: :thin } ]
      end
    end

    # 摘要欄に書く文字(出荷案内書は空欄)。idxは何件目か(0始まり)
    def remark_text(_idx)
      nil
    end

    # 直前の行の摘要(F:G)を1つのセルにする
    def merge_remark(sheet)
      row = sheet.rows.size
      sheet.merge_cells("F#{row}:G#{row}")
    end

    # 出荷案内書には、小計・累計・合計・取引銀行が無い
    def build_footer(_sheet, **_options); end
  end
end
