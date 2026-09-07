# frozen_string_literal: true

module XlsxReports
  # 請求書(seikyu.xls相当)。Order 1件+その明細(Orderpart)からxlsxを生成する。
  class SeikyuReport < TabularReport
    COMPANY_NAME = "神戸エンジンサービス株式会社"
    COMPANY_ADDRESS = "神戸市長田区東尻池町9丁目1番12号"
    COMPANY_TEL = "電話神戸(078)651-2997(代)"
    COMPANY_FAX = "FAX　　　(078)651-2625"

    def initialize(order)
      @order = order
      # adlist_idはadlistsのid ではなく no列を指すという既存実装(orders/show.html.haml)の慣習に合わせる
      @adlist = Adlist.find_by(no: order.adlist_id.to_s)
      @orderparts = Orderpart.where(mno: order.mno).reorder(:sno)
    end

    def filename
      "seikyu_#{@order.mno}.xlsx"
    end

    private

    def columns
      [
        Column.new(key: :no, label: "No.", width: 4, halign: :center),
        Column.new(key: :partno, label: "品番", width: 14, halign: :left),
        Column.new(key: :name, label: "品名・仕様", width: 34, halign: :left),
        Column.new(key: :qty, label: "数量", width: 6, halign: :right),
        Column.new(key: :unit, label: "単位", width: 6, halign: :center),
        Column.new(key: :price, label: "単価", width: 12, halign: :right, number_format: "#,##0"),
        Column.new(key: :amount, label: "金額", width: 14, halign: :right, number_format: "#,##0", total: true)
      ]
    end

    def build(workbook)
      workbook.add_worksheet(name: "請求書") do |sheet|
        build_header(sheet)
        items = build_items
        build_item_table(sheet, items: items, total: { amount: items.sum { |i| i[:amount] } })
        set_column_widths(sheet, *columns.map(&:width))
      end
    end

    def build_header(sheet)
      recipient_style = style(sheet, size: 14, bold: true, bottom: :medium)
      company_style = style(sheet, size: 11)

      sheet.add_row [ @adlist&.company ], style: [ recipient_style ]
      sheet.add_row [ @adlist&.section ], style: [ style(sheet, size: 11) ]
      sheet.add_row [ nil, nil, nil, nil, COMPANY_NAME ], style: [ nil, nil, nil, nil, style(sheet, size: 12, bold: true) ]
      sheet.add_row [ nil, nil, nil, nil, COMPANY_ADDRESS ], style: [ nil, nil, nil, nil, company_style ]
      sheet.add_row [ nil, nil, nil, nil, COMPANY_TEL ], style: [ nil, nil, nil, nil, company_style ]
      sheet.add_row [ nil, nil, nil, nil, COMPANY_FAX ], style: [ nil, nil, nil, nil, company_style ]
      sheet.add_row []

      info_header_style = style(sheet, border: :thin, halign: :center, size: 8)
      info_value_style = style(sheet, border: :thin, halign: :center, bold: true, size: 11)
      sheet.add_row [ "注番", "船名", "型式", "ENG.No." ], style: Array.new(4) { info_header_style }
      sheet.add_row [ @order.ono, @order.shipname, @order.etype, @order.engno ], style: Array.new(4) { info_value_style }
      sheet.add_row []
    end

    def build_items
      @orderparts.map do |orderpart|
        # orders/show.html.haml と同じく、Part台帳になければKepart(KE部品)台帳も見る
        part = Part.find_by(pcode: orderpart.partno) || Kepart.find_by(pcode: orderpart.partno)
        amount = (orderpart.irate.to_f * orderpart.qty.to_f * orderpart.unitpd.to_f).round
        {
          no: orderpart.sno,
          partno: orderpart.partno,
          name: [ part&.jname, orderpart.info ].compact_blank.join(" "),
          qty: orderpart.qty,
          unit: orderpart.unit,
          price: orderpart.unitpd,
          amount: amount
        }
      end
    end
  end
end
