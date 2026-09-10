# frozen_string_literal: true

module XlsxReports
  # 受注メモ(jutyu.xls / asp/jutyu111.asp相当)。
  # Order 1件+その明細(Orderpart)からxlsxを生成する。
  # 旧ASPは客先側にクライアントExcelを直接COM操作して手書き伝票のように仕上げる方式だったが、
  # ここではSeikyuReportと同じくサーバー側でTabularReportの型に沿って組み立てる。
  # ページ制御(1ページ目18件/2ページ目以降18件ずつ)は旧asp/jutyu111.asp準拠。
  class JuchuMemoReport < TabularReport
    FIRST_PAGE_ITEMS = 18
    CONTINUATION_PAGE_ITEMS = 18

    def initialize(order)
      @order = order
      @adlist = Adlist.find_by(no: order.adlist_id.to_s)
      # 部品番号あり(Orderpart)・無(NOrderpart)を「順(SNo)」で一本化した明細一覧。
      # orders#sorted画面と共有するOrderSortedItems参照。
      @items = OrderSortedItems.for(order)
    end

    def filename
      "juchu_memo_#{@order.mno}.xlsx"
    end

    private

    # 列幅の定義にのみ使う(明細行はcolumnsを介さず2行1組で個別に組み立てるため)
    def columns
      [
        Column.new(key: :code, width: 16),
        Column.new(key: :name, width: 34),
        Column.new(key: :qty, width: 7),
        Column.new(key: :unit, width: 7),
        Column.new(key: :blank, width: 3),
        Column.new(key: :price, width: 11),
        Column.new(key: :oprice, width: 11),
        Column.new(key: :amount, width: 14)
      ]
    end

    def build(workbook)
      items = build_items
      pages = paginate_items(items, FIRST_PAGE_ITEMS, CONTINUATION_PAGE_ITEMS)
      cumulative = 0

      pages.each_with_index do |page_items, idx|
        page_no = idx + 1
        is_last = page_no == pages.size

        workbook.add_worksheet(name: "#{page_no}枚目") do |sheet|
          sheet.page_setup.fit_to_width = 1
          sheet.page_setup.fit_to_height = 0
          sheet.page_setup.paper_size = 9
          sheet.page_margins.set(top: 0.4, bottom: 0.3, left: 0.6, right: 0.3, header: 0, footer: 0)

          build_header(sheet, page_no)
          build_two_row_items(sheet, page_items)

          page_subtotal = page_items.sum { |item| item[:amount] }
          cumulative += page_subtotal
          build_footer(sheet, total_pages: pages.size, page_subtotal: page_subtotal, cumulative: cumulative)

          build_comment(sheet) if page_no == 1 && @order.memo.present?

          set_column_widths(sheet, *columns.map(&:width))
        end
      end
    end

    def build_header(sheet, page_no)
      title_style = style(sheet, size: 16, bold: true, halign: :center)
      sheet.add_row([ nil, "受注メモ", nil, nil, nil, nil, "No." ],
                     style: [ nil, title_style, title_style, title_style, nil, nil, style(sheet, halign: :right) ])
      sheet.merge_cells("B#{sheet.rows.size}:D#{sheet.rows.size}")
      set_last_row_height(sheet, 22)
      sheet.add_row([ nil, nil, nil, nil, nil, nil, @order.mno, page_no.to_s ],
                     style: [ nil, nil, nil, nil, nil, nil, style(sheet, halign: :right), style(sheet, halign: :right) ])
      set_last_row_height(sheet, 13)

      box_label = style(sheet, border: :thin, halign: :left, size: 8)
      box_value = style(sheet, border: :thin, halign: :center)

      sheet.add_row([ "客先No.", @adlist&.no, nil, nil, nil, "期限", @order.rdate&.strftime("%Y/%m/%d") ],
                     style: [ box_label, box_value, box_value, box_value, box_value, box_label, box_value ])
      set_last_row_height(sheet, 14)
      row = sheet.rows.size
      sheet.merge_cells("B#{row}:E#{row}")

      sheet.add_row([ nil, [ @adlist&.company, @adlist&.section ].compact.join("　") ],
                     style: [ box_label, style(sheet, border: :thin, halign: :left) ])
      set_last_row_height(sheet, 16)
      row = sheet.rows.size
      sheet.merge_cells("B#{row}:G#{row}")

      sheet.add_row([ "型式", @order.etype, nil, nil, "船籍", @order.country ],
                     style: [ box_label, box_value, box_value, box_label, box_value, box_value ])
      set_last_row_height(sheet, 14)
      row = sheet.rows.size
      sheet.merge_cells("B#{row}:C#{row}")
      sheet.merge_cells("F#{row}:G#{row}")

      sheet.add_row([ "E/#", @order.engno ],
                     style: [ box_label, box_value ])
      set_last_row_height(sheet, 14)
      row = sheet.rows.size
      sheet.merge_cells("B#{row}:G#{row}")
    end

    # 1明細=2行(1行目:備考、2行目:部品コード/品名/数量/単位/単価/金額)。旧ASPの列構成に合わせている。
    def build_two_row_items(sheet, items)
      header_style = style(sheet, border: :thin, bold: true, halign: :center, valign: :center, fill: "FFC0C0C0")
      sheet.add_row([ "品名コード", "品名", "数量", "単位", nil, "単価", nil, "金額" ], style: Array.new(8) { header_style })
      sheet.merge_cells("F#{sheet.rows.size}:G#{sheet.rows.size}")
      set_last_row_height(sheet, 14)
      sheet.add_row([ "部品コード", nil, nil, nil, nil, "定価", "海外", nil ], style: Array.new(8) { header_style })
      set_last_row_height(sheet, 14)

      items.each do |item|
        row1_default = style(sheet, top: :thin, left: :thin, right: :thin)
        row2_default = style(sheet, bottom: :thin, left: :thin, right: :thin)

        sheet.add_row(
          [ nil, item[:info], nil, nil, nil, nil, nil, nil ],
          style: Array.new(8) { row1_default }
        )
        set_last_row_height(sheet, 13)
        sheet.add_row(
          [ item[:code], item[:name], item[:qty], item[:unit], nil, item[:price], item[:oprice], item[:amount] ],
          style: [
            row2_default,
            row2_default,
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right),
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :center),
            row2_default,
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right, number_format: "#,##0"),
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right, number_format: "#,##0"),
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right, number_format: "#,##0")
          ]
        )
        set_last_row_height(sheet, 13)
      end
    end

    def build_items
      @items.map do |item|
        {
          code: item.code,
          info: item.info,
          name: item.name,
          qty: item.qty,
          unit: item.unit,
          price: item.unitpd,
          oprice: nil,
          amount: item.amount
        }
      end
    end

    def add_summary_row(sheet, label, value)
      label_style = style(sheet, border: :thin, halign: :right, bold: true)
      value_style = style(sheet, border: :thin, halign: :right, bold: true, number_format: "#,##0")
      sheet.add_row([ nil, nil, nil, nil, nil, nil, label, value ],
                     style: [ nil, nil, nil, nil, nil, nil, label_style, value_style ])
      set_last_row_height(sheet, 14)
    end

    def build_footer(sheet, total_pages:, page_subtotal:, cumulative:)
      add_summary_row(sheet, "小計", page_subtotal)
      add_summary_row(sheet, "累計", cumulative) if total_pages > 1
    end

    def build_comment(sheet)
      sheet.add_row([])
      set_last_row_height(sheet, 6)
      sheet.add_row([ "備考", @order.memo ],
                     style: [ style(sheet, halign: :left, bold: true), style(sheet, halign: :left) ])
      row = sheet.rows.size
      sheet.merge_cells("B#{row}:H#{row}")
    end
  end
end
