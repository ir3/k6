# frozen_string_literal: true

module XlsxReports
  # 部品見積依頼票(print21_.xls / asp/print211_.asp 部品見積依頼2相当)。
  # 新潟部品(IHI原動機)へ送る所定様式の見積依頼書。
  #
  # 旧ASPは48列のマス目に1ページ目5件・2枚目以降15件ずつ(別シート方式)で書き込んでいた。
  # ここでは用紙の見た目に合わせた20列のグリッドに組み直している(列の対応はCOLUMN_PXのコメント参照)。
  class MitsumoriIraiReport < TabularReport
    COMPANY_NAME = "神戸エンジンサービス(株)"

    FIRST_PAGE_ITEMS = 5
    CONTINUATION_PAGE_ITEMS = 15

    # 列幅(px)。用紙(print21_.xls)の縦線位置に合わせて決めた20列で、表の各欄は次の列を結合して作る。
    #   No.=1 / 品名=2 / 部品コード・ItemNo・仕様=3-9 / 数量=10 / 単価=11-16 / 納期=17-18 / 重量=19-20
    COLUMN_PX = [ 55, 310, 40, 50, 65, 45, 185, 50, 55, 114, 19, 50, 22, 58, 50, 21, 87, 79, 38, 117 ].freeze

    def initialize(order)
      @order = order
      @adlist = Adlist.find_by(no: order.adlist_id.to_s)
      # 部品メーカーへの依頼なので、部品番号を持つ明細(Orderpart)だけを対象にする
      @items = OrderSortedItems.for(order).select { |item| item.source == :orderpart }
    end

    def filename
      "mitsumori_irai_#{@order.mno}.xlsx"
    end

    private

    def columns
      COLUMN_PX.map { |px| Column.new(key: :grid, width: ((px - 5) / 7.0).round(1)) }
    end

    def build(workbook)
      pages = paginate_items(build_items, FIRST_PAGE_ITEMS, CONTINUATION_PAGE_ITEMS)

      pages.each_with_index do |page_items, idx|
        page_no = idx + 1
        workbook.add_worksheet(name: "#{page_no}枚目") do |sheet|
          sheet.page_setup.orientation = :landscape
          sheet.page_setup.paper_size = 9
          sheet.page_setup.fit_to_width = 1
          sheet.page_setup.fit_to_height = 1
          sheet.page_margins.set(top: 0.3, bottom: 0.3, left: 0.4, right: 0.3, header: 0, footer: 0)

          grid = Grid.new(page_no == 1 ? 24 : 23, COLUMN_PX.size)
          if page_no == 1
            build_cover(grid, page_items, page_no, pages.size)
          else
            build_continuation(grid, page_items, page_no, pages.size)
          end
          grid.emit(sheet, self)
          set_column_widths(sheet, *columns.map(&:width))
        end
      end
    end

    # --- 1枚目(表紙) -------------------------------------------------------

    def build_cover(grid, page_items, page_no, total_pages)
      today = Date.current
      grid.height(1, 14)
      grid.text(1, 1, 4, "IHI原動機株式会社", size: 9, halign: :left)

      grid.height(2, 24)
      grid.text(2, 2, 9, "部品見積依頼票 [現装同一、追設・改造]", size: 16, bold: true, halign: :left)
      grid.text(2, 15, 18, "#{today.year}年 #{today.month}月 #{today.day}日", halign: :right)
      grid.text(2, 19, 20, "P #{page_no}／#{total_pages}", halign: :left)

      grid.height(3, 16)
      grid.text(3, 1, 1, "[宛先]", bold: true, halign: :left)
      grid.text(3, 13, 15, "[発行部門]", bold: true, halign: :left)

      grid.height(4, 19)
      grid.text(4, 1, 2, "原価管理チーム", bold: true, halign: :left)
      grid.text(4, 3, 3, "殿", bold: true, halign: :right)
      grid.line(4, 1, 3, :bottom)
      grid.text(4, 5, 6, "船名/客先", bold: true, halign: :left)
      grid.text(4, 7, 12, " #{@order.shipname}/#{@adlist&.company}", halign: :left)
      grid.line(4, 5, 12, :bottom)
      grid.text(4, 13, 15, "代 理 店", bold: true, halign: :left)
      grid.text(4, 16, 20, COMPANY_NAME, halign: :left)
      grid.line(4, 13, 20, :bottom)

      grid.height(5, 18)
      grid.text(5, 5, 6, "国籍", bold: true, halign: :left)
      grid.text(5, 7, 7, @order.country, halign: :left)
      grid.text(5, 8, 8, "検査", bold: true, halign: :left)
      grid.line(5, 5, 11, :bottom)
      grid.text(5, 13, 15, "営業担当", bold: true, halign: :left)
      grid.text(5, 16, 20, Ksystem.sales_person, halign: :left)
      grid.line(5, 13, 20, :bottom)

      # 機種欄(5行)。左は宛先、右は回答希望日・見積No.・見積有効期限が同じ行に並ぶ
      grid.height(6, 18)
      grid.text(6, 1, 2, "ニコ精密器(株)・生管", bold: true, halign: :left)
      grid.text(6, 3, 3, "殿", bold: true, halign: :right)
      grid.line(6, 1, 3, :bottom)
      grid.height(7, 18)
      grid.text(7, 1, 2, "日立ニコ大宮・生管", bold: true, halign: :left)
      grid.text(7, 3, 3, "殿", bold: true, halign: :right)

      engine_rows = [
        [ "ＤＥ形式", @order.etype, @order.engno ],
        [ "Ｔ／Ｃ形式", @order.tc, @order.tcno ],
        [ "ＺＰ形式", @order.zp, @order.zpno ],
        [ "ＧＬＣ形式", @order.glc, @order.glcno ],
        [ "ＭＧ／ＣＬ形式", @order.mg, @order.mgno ]
      ]
      engine_rows.each_with_index do |(label, type, no), i|
        r = 6 + i
        grid.height(r, 18)
        grid.text(r, 5, 6, label, size: 9, halign: :left)
        grid.text(r, 7, 7, type, halign: :left)
        grid.text(r, 8, 8, "No.", bold: true, halign: :left)
        grid.text(r, 9, 11, no, halign: :left)
        grid.text(r, 12, 12, "□", halign: :center)
        grid.line(r, 5, 11, :bottom)
      end

      grid.text(7, 15, 17, "回答希望日", bold: true, halign: :left)
      grid.text(7, 18, 20, "年　　月　　日", halign: :right)
      grid.line(7, 15, 20, :bottom)

      grid.text(8, 13, 14, "見積No.", bold: true, halign: :right, valign: :center, rows: 2)
      grid.text(8, 15, 20, @order.mno, size: 16, bold: true, halign: :center, valign: :center, rows: 2)
      grid.box(8, 15, 9, 20, :medium)

      grid.height(11, 22)
      grid.text(11, 5, 11, "対象機番の確認チェック印をお願いします", bold: true, halign: :left, valign: :center)
      grid.box(11, 5, 11, 11, :thin)
      grid.text(11, 12, 12, "↑", halign: :center)
      grid.text(11, 15, 17, "見積有効期限", bold: true, halign: :left)
      grid.text(11, 18, 20, "年　　月　　日", halign: :right)
      grid.line(11, 15, 20, :bottom)

      grid.height(12, 10)
      build_table(grid, 13, page_items, FIRST_PAGE_ITEMS, first_page: true)
      build_cover_footer(grid, 13 + 1 + FIRST_PAGE_ITEMS)
    end

    def build_cover_footer(grid, start_row)
      grid.height(start_row, 13)
      grid.text(start_row, 11, 18, "※価格には消費税が含まれておりません", size: 9, halign: :right)

      top = start_row + 1
      grid.height(top, 18)
      grid.height(top + 1, 18)
      grid.height(top + 2, 39)
      grid.height(top + 3, 39)
      grid.text(top, 1, 1, vertical_text("代理店・営業見積理由"), size: 8, halign: :center, valign: :center, rows: 4, wrap: true)
      grid.box(top, 1, top + 3, 1, :thin)
      grid.box(top, 2, top + 3, 5, :thin)
      grid.text(top, 6, 6, vertical_text("原価管理連絡事項"), size: 8, halign: :center, valign: :center, rows: 4, wrap: true)
      grid.box(top, 6, top + 3, 6, :thin)
      grid.box(top, 7, top + 3, 13, :thin)

      grid.text(top, 14, 17, "営 業 部 門", bold: true, halign: :center, valign: :center)
      grid.box(top, 14, top, 17, :thin)
      grid.text(top, 18, 20, "原価管理チーム", bold: true, halign: :center, valign: :center)
      grid.box(top, 18, top, 20, :thin)
      [ [ 14, 15, "承 認" ], [ 16, 17, "担 当" ], [ 18, 19, "承 認" ], [ 20, 20, "担 当" ] ].each do |c1, c2, label|
        grid.text(top + 1, c1, c2, label, bold: true, halign: :center, valign: :center)
        grid.box(top + 1, c1, top + 1, c2, :thin)
        grid.box(top + 2, c1, top + 3, c2, :thin)
      end

      grid.height(top + 4, 14)
      grid.text(top + 4, 1, 6, "Ｑ７２ＣＴ１０１（様式－１）改正２", size: 9, halign: :left)
    end

    # --- 2枚目以降(次紙) -----------------------------------------------------

    def build_continuation(grid, page_items, page_no, total_pages)
      grid.height(1, 14)
      grid.text(1, 1, 4, "IHI原動機株式会社", size: 9, halign: :left)

      grid.height(2, 26)
      grid.text(2, 1, 6, "部品見積依頼票 [現装同一、追設・改造]", size: 16, bold: true, halign: :left)
      grid.text(2, 7, 8, "ＤＥ形式　#{@order.etype}", bold: true, halign: :left)
      grid.line(2, 7, 8, :bottom)
      grid.text(2, 9, 12, "製造番号　#{@order.engno}", bold: true, halign: :left)
      grid.line(2, 9, 12, :bottom)
      grid.text(2, 14, 15, "見積No.", bold: true, halign: :right)
      grid.text(2, 16, 18, @order.mno, halign: :center)
      grid.line(2, 16, 18, :bottom)
      grid.text(2, 19, 20, "P #{page_no}／#{total_pages}", halign: :left)

      grid.height(3, 8)
      build_table(grid, 4, page_items, CONTINUATION_PAGE_ITEMS, first_page: false)

      note_row = 4 + 1 + CONTINUATION_PAGE_ITEMS
      grid.height(note_row, 13)
      grid.text(note_row, 11, 18, "※価格には消費税が含まれておりません", size: 9, halign: :right)
      grid.height(note_row + 1, 40)
      grid.height(note_row + 2, 40)
      grid.text(note_row + 1, 1, 1, vertical_text("原価管理連絡事項"), size: 8, halign: :center, valign: :center, rows: 2, wrap: true)
      grid.box(note_row + 1, 1, note_row + 2, 1, :thin)
      grid.box(note_row + 1, 2, note_row + 2, 20, :thin)
      grid.height(note_row + 3, 14)
      grid.text(note_row + 3, 1, 6, "Ｑ７２ＣＴ１０１（様式－１）改正２", size: 9, halign: :left)
    end

    # --- 明細表 ------------------------------------------------------------

    def build_table(grid, header_row, page_items, capacity, first_page:)
      grid.height(header_row, first_page ? 31 : 34)
      [
        [ 1, 1, "No." ], [ 2, 2, "品　　　名" ], [ 3, 9, "部品コード／Item No.／仕様" ],
        [ 10, 10, "数　量" ], [ 11, 16, "単　価" ], [ 17, 18, "納　期\n(要・否)" ], [ 19, 20, "重　量\n(要・否)" ]
      ].each do |c1, c2, label|
        grid.text(header_row, c1, c2, label, bold: true, halign: :center, valign: :center, wrap: true)
        grid.box(header_row, c1, header_row, c2, :thin)
      end

      row_height = first_page ? 24 : 26
      capacity.times do |i|
        r = header_row + 1 + i
        grid.height(r, row_height)
        item = page_items[i]
        fill_item(grid, r, item, first_page: first_page) if item
        [ [ 1, 1 ], [ 2, 2 ], [ 3, 9 ], [ 10, 10 ], [ 11, 16 ], [ 17, 18 ], [ 19, 20 ] ].each do |c1, c2|
          grid.box(r, c1, r, c2, :thin)
        end
      end
    end

    def fill_item(grid, row, item, first_page:)
      grid.text(row, 1, 1, item[:no], halign: :center, valign: :center)

      # 旧ASP: 備考が数字で始まる場合は、次紙に限り品名と備考をまとめて「仕様」欄へ出す
      spec_in_code_column = !first_page && item[:info].to_s.match?(/\A[0-9０-９]/)
      if spec_in_code_column
        grid.text(row, 8, 9, item[:name_info], size: 9, halign: :left, valign: :center, wrap: true)
      else
        grid.text(row, 2, 2, item[:name_info], size: 10, halign: :left, valign: :center, wrap: true)
      end
      grid.text(row, 3, 5, item[:code], halign: :left, valign: :center)
      grid.text(row, 6, 7, item[:itemno], halign: :left, valign: :center)

      grid.text(row, 10, 10, item[:qty_unit], halign: :right, valign: :center)

      if item[:old_price]
        grid.text(row, 11, 13, item[:old_price], size: 12, halign: :right, valign: :center, number_format: "#,##0")
        grid.text(row, 14, 16, item[:new_price], size: 12, halign: :right, valign: :center, number_format: "#,##0")
      elsif item[:price]
        grid.text(row, 11, 13, item[:price], size: 12, halign: :right, valign: :center, number_format: "#,##0")
      end

      grid.text(row, 19, 20, item[:weight], halign: :right, valign: :center) if item[:weight]
    end

    # --- 明細データ ----------------------------------------------------------

    def build_items
      @items.each_with_index.map do |item, idx|
        prices = unit_prices(item)
        {
          no: idx + 1,
          name_info: [ item.name, item.info ].compact_blank.join("　"),
          info: item.info,
          code: item.code,
          itemno: item.itemno,
          qty_unit: [ format_number(item.qty), item.unit ].compact_blank.join(" "),
          weight: (item.totalweight.round(2) if item.totalweight.to_f.positive? && item.totalweight.to_f != 999),
          **prices
        }
      end
    end

    # 旧ASPの単価処理。掛け率が1を超えるときは「旧単価(定価)」と「新単価(定価×掛け率を丸めたもの)」の
    # 2つを出し、そうでなければ(掛け率なし=0は1扱い)丸めた単価を1つだけ出す。単価0の行は出さない。
    def unit_prices(item)
      list_price = item.unitpd.to_i
      return {} unless list_price.positive?

      rate = item.rate.to_f
      if rate > 1.0
        { old_price: list_price, new_price: PriceRounding.smarume(list_price * rate) }
      else
        rate = 1.0 if rate.zero?
        { price: PriceRounding.smarume(list_price * rate) }
      end
    end

    def format_number(value)
      return nil if value.nil?

      value.to_f == value.to_i ? value.to_i : value
    end

    # 縦書きの代わりに1文字ずつ改行して縦に並べる
    def vertical_text(text)
      text.chars.join("\n")
    end

    # --- セルの方眼 --------------------------------------------------------------

    # 行×列の方眼にセルの値・書式・罫線・結合をためておき、最後にまとめてシートへ書き出す。
    # (caxlsxは行単位で追加するため、結合範囲の各セルへ罫線を割り当てる作業を方眼側でやる)
    class Grid
      def initialize(rows, cols)
        @cols = cols
        @cells = Array.new(rows) { Array.new(cols) { { value: nil, attrs: {} } } }
        @heights = {}
        @merges = []
      end

      def height(row, points)
        @heights[row] = points
      end

      # row行のcol1〜col2列(rows指定で複数行)に値を置いて結合する
      def text(row, col1, col2, value, rows: 1, **attrs)
        row2 = row + rows - 1
        @cells[row - 1][col1 - 1][:value] = value
        (row..row2).each do |r|
          (col1..col2).each { |c| @cells[r - 1][c - 1][:attrs].merge!(attrs) }
        end
        @merges << [ row, col1, row2, col2 ] if row2 > row || col2 > col1
      end

      # 範囲の外周に罫線を引く
      def box(row1, col1, row2, col2, kind)
        (col1..col2).each do |c|
          edge(row1, c, :top, kind)
          edge(row2, c, :bottom, kind)
        end
        (row1..row2).each do |r|
          edge(r, col1, :left, kind)
          edge(r, col2, :right, kind)
        end
      end

      # 範囲の片側だけに線を引く(下線など)
      def line(row, col1, col2, side)
        (col1..col2).each { |c| edge(row, c, side, :thin) }
      end

      def emit(sheet, report)
        @cells.each_with_index do |cells, idx|
          styles = cells.map { |cell| cell[:attrs].empty? ? nil : report.send(:style, sheet, **cell[:attrs]) }
          sheet.add_row(cells.map { |cell| cell[:value] }, style: styles)
          report.send(:set_last_row_height, sheet, @heights[idx + 1] || 16)
        end
        @merges.each do |row1, col1, row2, col2|
          sheet.merge_cells("#{letter(col1)}#{row1}:#{letter(col2)}#{row2}")
        end
      end

      private

      def edge(row, col, side, kind)
        @cells[row - 1][col - 1][:attrs][side] = kind
      end

      def letter(col)
        ("A".ord + col - 1).chr
      end
    end
  end
end
