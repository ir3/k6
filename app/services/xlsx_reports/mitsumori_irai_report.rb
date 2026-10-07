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
    COLUMN_PX = [ 55, 310, 40, 50, 70, 45, 185, 50, 55, 60, 19, 50, 22, 58, 22, 21, 60, 42, 38, 80 ].freeze

    # 数量(J列=20列の10番目)の右に、単位(袋など)の列を1つ追加している。build_cover等の列番号は
    # 追加前の20列のままで書き、Gridが実際の列へ直す(UNIT_COLが追加した列。11列目以降は1つ右へ)。
    # 数量と単位をまたぐ結合は 10 〜 UNIT_COL と書く。
    UNIT_COL = 10.5
    UNIT_COLUMN_PX = 50
    GRID_COLUMN_PX = COLUMN_PX.dup.insert(10, UNIT_COLUMN_PX).freeze

    # 1枚目の行間の隙間(空白行)。build_coverの行番号は「隙間を入れる前」の番号で書いてあり、
    # COVER_BLANK_AFTER の各行の直後に空白行を1行ずつ挿入して実際の行へ直す(cover_row)。
    # 8行目・12行目は元から空白行として確保してある。
    COVER_BLANK_AFTER = [ 4, 5, 6, 9, 10 ].freeze
    BLANK_ROW_HEIGHT = 6
    COVER_LINE_HEIGHT = 24 # 表紙の国籍・宛先・形式の各行の高さ(pt)

    # 文字は、各所に書いたサイズより2pt大きく出す(Grid#text)。DEFAULT_TEXT_SIZEはサイズ省略時のBaseReport#styleの既定値
    DEFAULT_TEXT_SIZE = 11
    TEXT_SIZE_UP = 2

    # フォント。この帳票は明朝系にしている(他の帳票はBaseReportの既定のMS PGothic)。
    # MS PMinchoはWindowsのOfficeにもMac版Excelにも入っている。
    FONT_NAME = "MS PMincho"
    GOTHIC_FONT_NAME = "MS PGothic" # 部分的にゴシックにするとき(Grid#textのfont_name:)

    # Item No.の初期値(「1」「0」)は意味を持たないので表示しない
    DEFAULT_ITEMNOS = %w[1 0].freeze

    def initialize(order)
      @order = order
      @adlist = Adlist.find_by(no: order.adlist_id.to_s)
      # 部品メーカーへの依頼なので、部品番号を持つ明細(Orderpart)だけを対象にする
      @items = OrderSortedItems.for(order).select { |item| item.source == :orderpart }
    end

    def filename
      "mitsumori_irai_#{@order.mno}.xlsx"
    end

    # 「対象機番の確認チェック印」の枠から1行上の□へ向かう折れ線矢印は、caxlsxに図形のAPIが
    # 無いため、生成済みのxlsxの1枚目へ図形をXMLで後から挿入する(SeikyuReportと同じ手法)。
    def generate
      ShapePatchedPackage.new(super, method(:inject_arrow))
    end

    private

    # 矢印の位置(1枚目)。確認枠の右辺の中央から、L列の中央まで右へ伸ばし、そこから上へ(□の下まで)。
    # 0始まりの列・行で、枠の右辺=L列の左端、矢印の先端=□の下の空白行(旧12行目)の上端。
    # L列の幅はCOLUMN_PX、確認枠の行は高さ22pt。
    ARROW_COL = 12 # 追加した単位の列の分、旧L列(index 11)より1つ右
    ARROW_ROW = 12 + COVER_BLANK_AFTER.count { |n| n < 12 } - 1 # 空白行(旧12行目)の上端
    ARROW_ROW_HEIGHT_EMU = 22 * 12_700
    ARROW_COL_WIDTH_EMU = GRID_COLUMN_PX[ARROW_COL] * 9_525

    def inject_arrow(path)
      ShapePatchedPackage.inject_drawing(path, arrow_drawing_xml, rel_id: "rIdArrowDrawing")
    end

    # 左下から右へ伸び、折れて上へ向かう矢印。bentConnector2(左上→右→下)を flipV で上下反転して使い、
    # 矢じりは終点(上端)側に付ける。
    def arrow_drawing_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
        <xdr:twoCellAnchor>
        <xdr:from><xdr:col>#{ARROW_COL}</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>#{ARROW_ROW}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>
        <xdr:to><xdr:col>#{ARROW_COL}</xdr:col><xdr:colOff>#{ARROW_COL_WIDTH_EMU / 2}</xdr:colOff><xdr:row>#{ARROW_ROW + 1}</xdr:row><xdr:rowOff>#{ARROW_ROW_HEIGHT_EMU / 2}</xdr:rowOff></xdr:to>
        <xdr:cxnSp macro="">
        <xdr:nvCxnSpPr><xdr:cNvPr id="1" name="ConfirmArrow"/><xdr:cNvCxnSpPr/></xdr:nvCxnSpPr>
        <xdr:spPr>
        <a:xfrm flipV="1"><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm>
        <a:prstGeom prst="bentConnector2"><a:avLst/></a:prstGeom>
        <a:ln w="9525"><a:solidFill><a:srgbClr val="000000"/></a:solidFill><a:tailEnd type="triangle" w="med" len="med"/></a:ln>
        </xdr:spPr>
        </xdr:cxnSp>
        <xdr:clientData/>
        </xdr:twoCellAnchor>
        </xdr:wsDr>
      XML
    end

    def columns
      GRID_COLUMN_PX.map { |px| Column.new(key: :grid, width: ((px - 5) / 7.0).round(1)) }
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
          sheet.page_margins.set(top: 0.5, bottom: 0.1, left: 0.4, right: 0.3, header: 0, footer: 0)

          grid = Grid.new(page_no == 1 ? 26 + COVER_BLANK_AFTER.size : 23, GRID_COLUMN_PX.size)
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

    # 隙間を入れる前の行番号を、実際の行番号に直す
    def cover_row(n)
      n + COVER_BLANK_AFTER.count { |k| k < n }
    end

    def build_cover(grid, page_items, page_no, total_pages)
      today = Date.current
      grid.height(1, 20)
      grid.text(1, 1, 4, "IHI原動機株式会社", size: 11, halign: :left)

      grid.height(2, 32)
      grid.text(2, 2, 9, "部品見積依頼票 [現装同一、追設・改造]", size: 16, halign: :center)
      grid.text(2, 15, 18, "#{today.year}年 #{today.month}月 #{today.day}日", halign: :right)
      grid.text(2, 19, 20, "P #{page_no}／#{total_pages}", halign: :left)

      grid.height(3, 30)
      grid.text(3, 1, 1, "[宛先]", halign: :left)
      grid.text(3, 13, 15, "[発行部門]", halign: :left)
      grid.text(3, 18, 20, @order.mno, size: 11, halign: :center)

      grid.height(4, 33)
      grid.text(4, 1, 2, "原価管理チーム", halign: :left)
      grid.text(4, 3, 3, "殿", halign: :right)
      grid.line(4, 1, 3, :bottom)
      grid.text(4, 5, 6, "船名/客先", halign: :left)
      grid.text(4, 7, 12, " #{@order.shipname}/#{@adlist&.company}", size: 14, halign: :left)
      grid.line(4, 5, 12, :bottom)
      grid.text(4, 13, 15, "代 理 店", halign: :left)
      grid.text(4, 16, 20, COMPANY_NAME, halign: :left)
      grid.line(4, 13, 20, :bottom)

      grid.height(cover_row(5), COVER_LINE_HEIGHT)
      grid.text(cover_row(5), 5, 6, "国籍", halign: :left)
      grid.text(cover_row(5), 7, 7, @order.country, halign: :left)
      grid.text(cover_row(5), 8, 8, "検査", halign: :left)
      grid.line(cover_row(5), 5, 11, :bottom)
      grid.text(cover_row(5), 13, 15, "営業担当", halign: :left)
      grid.text(cover_row(5), 16, 20, Ksystem.sales_person, halign: :left)
      grid.line(cover_row(5), 13, 20, :bottom)

      # 機種欄(5行)。左は宛先、右は回答希望日・見積No.・見積有効期限が同じ行に並ぶ
      grid.height(cover_row(6), COVER_LINE_HEIGHT)
      grid.text(cover_row(6), 2, 2, "ニコ精密器(株)・生管", halign: :left)
      grid.text(cover_row(6), 3, 3, "殿", halign: :right)
      grid.line(cover_row(6), 2, 3, :bottom)
      grid.height(cover_row(7), COVER_LINE_HEIGHT)
      grid.text(cover_row(7), 2, 2, "日立ニコ大宮・生管", halign: :left)
      grid.text(cover_row(7), 3, 3, "殿", halign: :right)
      grid.line(cover_row(7), 2, 3, :bottom)

      engine_rows = [
        [ "ＤＥ形式", @order.etype, @order.engno ],
        [ "Ｔ／Ｃ形式", @order.tc, @order.tcno ],
        [ "ＺＰ形式", @order.zp, @order.zpno ],
        [ "ＧＬＣ形式", @order.glc, @order.glcno ],
        [ "ＭＧ／ＣＬ形式", @order.mg, @order.mgno ]
      ]
      engine_rows.each_with_index do |(label, type, no), i|
        # 7行目と8行目の間に空白行(8行目)が入るので、3つ目以降は1行下
        r = cover_row(i < 2 ? 6 + i : 7 + i)
        grid.height(r, COVER_LINE_HEIGHT)
        # E:F(115px)に「ＭＧ／ＣＬ形式」が収まる上限の12ptに固定(他の文字のように+2しない)
        grid.text(r, 5, 6, label, size: 12, fixed_size: true, halign: :left)
        grid.text(r, 7, 7, type, size: 15, halign: :left)
        grid.text(r, 8, 8, "No.", size: 13, halign: :left)
        grid.text(r, 9, 11, no, size: 15, halign: :left)
        grid.text(r, 12, 12, "□", size: 18, halign: :center)
        grid.line(r, 5, 11, :bottom)
      end

      grid.text(cover_row(7), 14, 17, "回答希望日", halign: :left)
      write_date_blank(grid, cover_row(7))
      grid.line(cover_row(7), 14, 20, :bottom)

      # 回答希望日の下線(O7:T7)と、見積No.の枠の上辺は別の線にするため、間に空白行(8行目)を入れる
      grid.text(cover_row(9), 13, 14, "見積No.", halign: :right, valign: :center, rows: cover_row(10) - cover_row(9) + 1)
      grid.box(cover_row(9), 15, cover_row(10), 20, :medium)

      # 11行目の下線と、確認枠(F13:K13)の上辺は別の線にするため、間に空白行(12行目)を入れる
      grid.height(cover_row(13), 28)
      # G列から枠(G:L)の中に、ゴシックの太字で書く(E:Fは空)
      grid.text(cover_row(13), 7, 11, "対象機番の確認チェック印をお願いします", bold: true, font_name: GOTHIC_FONT_NAME, halign: :left, valign: :center)
      grid.box(cover_row(13), 7, cover_row(13), 11, :thin)
      grid.text(cover_row(13), 14, 17, "見積有効期限", size: 12, fixed_size: true, halign: :left) # 12ptに固定(他の文字のように+2しない)
      write_date_blank(grid, cover_row(13))
      grid.line(cover_row(13), 14, 20, :bottom)

      # 行間の隙間にする空白行(高さ6pt)。追加した行(各行の直後)と、既にある8行目・12行目
      COVER_BLANK_AFTER.each { |n| grid.height(cover_row(n) + 1, BLANK_ROW_HEIGHT) }
      [ 8, 12 ].each { |n| grid.height(cover_row(n), BLANK_ROW_HEIGHT) }

      grid.height(cover_row(14), 10)
      build_table(grid, cover_row(15), page_items, FIRST_PAGE_ITEMS, first_page: true)
      build_cover_footer(grid, cover_row(15) + 1 + FIRST_PAGE_ITEMS)
    end

    # 手書き用の「年 月 日」。年は左のセルで左端から右へ(インデント3)。月と日は右の広いセルに
    # 全角空白をはさんで右寄せで書き、日を右端に置く。月の位置は空白の数(MONTH_DAY_GAP)で決まり、
    # 増やすと月が左へ、減らすと右へ動く(年と日のほぼ真ん中に来るように合わせてある)。
    MONTH_DAY_GAP = 3

    def write_date_blank(grid, row)
      grid.text(row, 18, 18, "年", halign: :left, indent: 3)
      grid.text(row, 20, 20, "月#{'　' * MONTH_DAY_GAP}日", halign: :right)
    end

    def build_cover_footer(grid, start_row)
      grid.height(start_row, 20)
      grid.text(start_row, 11, 18, "※価格には消費税が含まれておりません", size: 9, halign: :right)

      top = start_row + 1
      grid.height(top, 28.5)
      grid.height(top + 1, 28.5)
      grid.height(top + 2, 38)
      grid.height(top + 3, 38)
      grid.text(top, 1, 1, vertical_text("代理店・営業見積理由"), size: 8, halign: :center, valign: :center, rows: 4, wrap: true)
      grid.box(top, 1, top + 3, 1, :thin)
      grid.box(top, 2, top + 3, 5, :thin)
      grid.text(top, 6, 6, vertical_text("原価管理連絡事項"), size: 8, halign: :center, valign: :center, rows: 4, wrap: true)
      grid.box(top, 6, top + 3, 6, :thin)
      grid.box(top, 7, top + 3, 13, :thin)

      grid.text(top, 14, 17, "営 業 部 門", halign: :center, valign: :center)
      grid.box(top, 14, top, 17, :thin)
      grid.text(top, 18, 20, "原価管理チーム", halign: :center, valign: :center)
      grid.box(top, 18, top, 20, :thin)
      [ [ 14, 15, "承 認" ], [ 16, 17, "担 当" ], [ 18, 19, "承 認" ], [ 20, 20, "担 当" ] ].each do |c1, c2, label|
        grid.text(top + 1, c1, c2, label, halign: :center, valign: :center)
        grid.box(top + 1, c1, top + 1, c2, :thin)
        grid.box(top + 2, c1, top + 3, c2, :thin)
      end

      grid.height(top + 4, 14)
      grid.text(top + 4, 1, 6, "Ｑ７２ＣＴ１０１（様式－１）改正２", size: 9, halign: :left)
    end

    # --- 2枚目以降(次紙) -----------------------------------------------------

    def build_continuation(grid, page_items, page_no, total_pages)
      grid.height(1, 20)
      grid.text(1, 1, 4, "IHI原動機株式会社", size: 11, halign: :left)

      grid.height(2, 26)
      grid.text(2, 1, 6, "部品見積依頼票 [現装同一、追設・改造]", size: 16, halign: :left)
      grid.text(2, 7, 8, "ＤＥ形式　#{@order.etype}", halign: :left)
      grid.line(2, 7, 7, :bottom)
      grid.text(2, 9, 12, "製造番号　#{@order.engno}", halign: :left)
      grid.line(2, 9, 12, :bottom)
      grid.text(2, 14, 15, "見積No.", halign: :right)
      grid.line(2, 16, 18, :bottom)
      grid.text(2, 19, 20, "P #{page_no}／#{total_pages}", halign: :left)

      grid.height(3, 8)
      build_table(grid, 4, page_items, CONTINUATION_PAGE_ITEMS, first_page: false)

      note_row = 4 + 1 + CONTINUATION_PAGE_ITEMS
      grid.height(note_row, 13)
      grid.text(note_row, 11, 18, "※価格には消費税が含まれておりません", size: 9, halign: :right)
      grid.height(note_row + 1, 37.5)
      grid.height(note_row + 2, 37.5)
      # 2枚目以降の「原価管理連絡事項」は大きくしない(指定どおり)。枠の高さが低いので縦書き2列にする
      grid.text(note_row + 1, 1, 1, vertical_text_columns("原価管理連絡事項", 2), size: 8, fixed_size: true, halign: :center, valign: :center, rows: 2, wrap: true)
      grid.box(note_row + 1, 1, note_row + 2, 1, :thin)
      grid.box(note_row + 1, 2, note_row + 2, 20, :thin)
      grid.height(note_row + 3, 14)
      grid.text(note_row + 3, 1, 6, "Ｑ７２ＣＴ１０１（様式－１）改正２", size: 9, halign: :left)
    end

    # --- 明細表 ------------------------------------------------------------

    def build_table(grid, header_row, page_items, capacity, first_page:)
      grid.height(header_row, 38)
      [
        [ 1, 1, "No." ], [ 2, 2, "品　　　名" ], [ 3, 9, "部品コード／Item No.／仕様" ],
        [ 10, UNIT_COL, "数　量" ], [ 11, 16, "単　価" ], [ 17, 18, "納　期\n(要・否)" ], [ 19, 20, "重　量\n(要・否)" ]
      ].each do |c1, c2, label|
        grid.text(header_row, c1, c2, label, halign: :center, valign: :center, wrap: true)
        grid.box(header_row, c1, header_row, c2, :thin)
      end

      row_height = 35
      capacity.times do |i|
        r = header_row + 1 + i
        grid.height(r, row_height)
        item = page_items[i]
        fill_item(grid, r, item, first_page: first_page) if item
        [ [ 1, 1 ], [ 2, 2 ], [ 3, 9 ], [ 10, UNIT_COL ], [ 11, 16 ], [ 17, 18 ], [ 19, 20 ] ].each do |c1, c2|
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
      grid.text(row, 3, 5, item[:code], size: 13, halign: :left, valign: :center, indent: 1)
      grid.text(row, 6, 7, item[:itemno], halign: :left, valign: :center)

      grid.text(row, 10, 10, item[:qty], size: 14, halign: :right, valign: :center)
      grid.text(row, UNIT_COL, UNIT_COL, item[:unit_label], size: 14, halign: :left, valign: :center)

      if item[:old_price]
        grid.text(row, 11, 13, item[:old_price], size: 14, halign: :right, valign: :center, number_format: "#,##0")
        grid.text(row, 14, 16, item[:new_price], size: 14, halign: :right, valign: :center, number_format: "#,##0")
      elsif item[:price]
        grid.text(row, 11, 13, item[:price], size: 14, halign: :right, valign: :center, number_format: "#,##0")
      end

      grid.text(row, 19, 20, item[:weight], halign: :center, valign: :center, number_format: "0.000") if item[:weight]
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
          itemno: (item.itemno unless DEFAULT_ITEMNOS.include?(item.itemno.to_s.strip)),
          qty: format_number(item.qty),
          unit_label: unit_label(item.unit),
          weight: (item.totalweight.round(3) if item.totalweight.to_f.positive? && item.totalweight.to_f != 999),
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

    # 販売単位の表記。部品台帳の販売単位が数字(例: 10 = 10個で1袋)のときは「袋」、
    # SET・ｸﾐ・PCSなどの文字のときはそのまま出す。
    def unit_label(unit)
      unit = unit.to_s.strip
      return nil if unit.empty?

      unit.match?(/\A\d+(\.\d+)?\z/) ? "袋" : unit
    end

    def format_number(value)
      return nil if value.nil?

      value.to_f == value.to_i ? value.to_i : value
    end

    # 縦書きの代わりに1文字ずつ改行して縦に並べる
    def vertical_text(text)
      text.chars.join("\n")
    end

    # 縦書きをcolumns列にする(1文字ずつ改行して縦に並べるのと同じ方法)。縦書きなので、先頭の文字から
    # 順に右の列へ、あふれた分が左の列へ並ぶ。1行に各列の同じ段の文字を左の列から並べて書く。
    # 例: 「原価管理連絡事項」2列 → 右の列「原価管理」・左の列「連絡事項」→ 「連原」「絡価」「事管」「項理」の4行
    def vertical_text_columns(text, columns)
      lines = text.chars.each_slice((text.chars.size / columns.to_f).ceil).to_a
      lines.first.each_index.map { |i| lines.reverse.map { |col| col[i] || "　" }.join }.join("\n")
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
      # 文字サイズは指定(省略時11)より TEXT_SIZE_UP 大きくする。fixed_size: true のときだけ指定どおり。
      def text(row, col1, col2, value, rows: 1, fixed_size: false, **attrs)
        base_size = attrs[:size] || DEFAULT_TEXT_SIZE
        attrs[:size] = fixed_size ? base_size : base_size + TEXT_SIZE_UP
        col1 = physical(col1)
        col2 = physical(col2)
        row2 = row + rows - 1
        @cells[row - 1][col1 - 1][:value] = value
        (row..row2).each do |r|
          (col1..col2).each { |c| @cells[r - 1][c - 1][:attrs].merge!(attrs) }
        end
        @merges << [ row, col1, row2, col2 ] if row2 > row || col2 > col1
      end

      # 範囲の外周に罫線を引く
      def box(row1, col1, row2, col2, kind)
        col1 = physical(col1)
        col2 = physical(col2)
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
        col1 = physical(col1)
        col2 = physical(col2)
        (col1..col2).each { |c| edge(row, c, side, :thin) }
      end

      def emit(sheet, report)
        @cells.each_with_index do |cells, idx|
          styles = cells.map { |cell| cell[:attrs].empty? ? nil : report.send(:style, sheet, **{ font_name: FONT_NAME }.merge(cell[:attrs])) }
          sheet.add_row(cells.map { |cell| cell[:value] }, style: styles)
          report.send(:set_last_row_height, sheet, @heights[idx + 1] || 16)
        end
        @merges.each do |row1, col1, row2, col2|
          sheet.merge_cells("#{letter(col1)}#{row1}:#{letter(col2)}#{row2}")
        end
      end

      private

      # 追加前の20列の番号(UNIT_COLを含む)を、実際の列番号へ直す。11列目以降は追加した1列の分だけ右へ
      def physical(col)
        return col if col <= 10

        col == UNIT_COL ? 11 : col + 1
      end

      def edge(row, col, side, kind)
        @cells[row - 1][col - 1][:attrs][side] = kind
      end

      def letter(col)
        ("A".ord + col - 1).chr
      end
    end
  end
end
