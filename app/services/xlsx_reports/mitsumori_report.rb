# frozen_string_literal: true

module XlsxReports
  # 御見積書(部品番号あり)(print11.xls / asp/print111r.asp相当)。
  # 客先へ出す見積書で、1ページ目(「見積書」シート)は明細15件、2ページ目以降(「見積書２」シート)は
  # 25件ずつ。明細は1件2行1組(上段に部品番号・備考・ItemNo、下段に品名・数量・単価・金額)。
  # 部品番号なし(print311r.asp)は部品番号を出さないだけなので、show_part_no? を false にしたサブクラスで作る。
  class MitsumoriReport < BaseReport
    FIRST_PAGE_ITEMS = 15
    CONTINUATION_PAGE_ITEMS = 25

    # A:No. / B:品名・仕様 / C:数量 / D:単位 / E:単価 / F:金額 / G:総重量(kg)。文字数単位(旧様式のまま)
    COLUMN_WIDTHS = [ 6.2, 40.6, 7.2, 7.0, 13.6, 18.2, 7.4 ].freeze
    COLUMN_COUNT = COLUMN_WIDTHS.size

    FONT_NAME = "MS PGothic"
    # Item No.の初期値(「1」「0」)は意味を持たないので表示しない(部品見積依頼票と同じ)
    DEFAULT_ITEMNOS = %w[1 0].freeze
    # 総重量の「不明」を表す値
    UNKNOWN_WEIGHT = 999

    def initialize(order)
      @order = order
      @adlist = Adlist.find_by(no: order.adlist_id.to_s)
      # 部品番号あり(Orderpart)・無(NOrderpart)を「順(SNo)」で一本化した明細一覧(受注メモと同じ)
      @items = OrderSortedItems.for(order)
    end

    def filename
      "mitsumori_#{@order.mno}.xlsx"
    end

    # 部品番号を出すか。部品番号なし見積(サブクラス)はfalse。
    def show_part_no?
      true
    end

    # 1ページ目の「承認」の2つの枠は、caxlsxに図形のAPIが無いため、生成済みのxlsxへXMLで後から挿入する。
    def generate
      ShapePatchedPackage.new(super, method(:inject_stamp_boxes))
    end

    private

    def build(workbook)
      pages = paginate(build_items)
      grand_total = pages.flatten.sum { |item| item[:amount].to_i }
      cumulative = 0

      pages.each_with_index do |page_items, idx|
        page_no = idx + 1
        last_page = page_no == pages.size
        page_total = page_items.sum { |item| item[:amount].to_i }
        cumulative += page_total

        workbook.add_worksheet(name: "#{page_no}枚目") do |sheet|
          setup_page(sheet)
          grid = Grid.new(page_no == 1 ? 58 : 57, COLUMN_COUNT, font_name: FONT_NAME)
          if page_no == 1
            build_cover(grid, page_items, grand_total: grand_total, page_total: page_total, last_page: last_page)
          else
            build_continuation(grid, page_items, page_no: page_no, page_total: page_total,
                                                  cumulative: cumulative, last_page: last_page)
          end
          grid.emit(sheet, self)
          set_column_widths(sheet, *COLUMN_WIDTHS)
        end
      end
    end

    def setup_page(sheet)
      sheet.page_setup.orientation = :portrait
      sheet.page_setup.paper_size = 9
      sheet.page_setup.fit_to_width = 1
      sheet.page_setup.fit_to_height = 1
      sheet.page_margins.set(top: 0.5, bottom: 0.5, left: 0.5, right: 0.5, header: 0, footer: 0)
    end

    # --- 1ページ目 ------------------------------------------------------------

    def build_cover(grid, page_items, grand_total:, page_total:, last_page:)
      # 旧様式(print11.xls「見積書」シート)の行の高さ
      {
        1 => 24, 2 => 19.5, 3 => 20.2, 4 => 13.5, 5 => 14.2, 6 => 17.2, 7 => 18.8, 8 => 13.5, 9 => 15.8,
        10 => 18.8, 11 => 15, 12 => 13.5, 13 => 13.5, 14 => 13.5, 15 => 13.5, 16 => 6, 17 => 13.5, 18 => 13.5,
        19 => 4.5, 20 => 3.8, 21 => 21, 22 => 18.8, 23 => 18, 24 => 27.8, 25 => 3.8
      }.each { |row, points| grid.height(row, points) }

      grid.text(1, 2, 4, "御見積書（正）", size: 18, halign: :center, valign: :center)
      grid.text(1, 7, 7, 1, halign: :center)
      grid.text(2, 5, 5, "No.", size: 12, bold: true, halign: :right)
      grid.text(2, 6, 6, @order.mno.to_s, size: 12, bold: true, halign: :left)
      write_customer(grid)

      grid.text(5, 1, 3, "御照会番号及日附", halign: :left)
      grid.text(5, 4, 6, "IHI原動機株式会社　代理店", size: 12, halign: :center)
      grid.text(6, 4, 6, "神戸エンジンサービス株式会社", size: 14, halign: :center)
      grid.text(6, 2, 2, @order.ono, halign: :center)
      grid.line(6, 2, 2, :bottom)
      grid.text(7, 2, 2, "下記の通り御見積申し上げます。", halign: :left)
      grid.text(7, 5, 6, "神戸市長田区東尻池町９丁目１番１２号", halign: :left)
      grid.text(8, 2, 2, "何卒御下命の程願い上げます。", halign: :left)
      grid.text(8, 5, 6, "電話神戸（０７８）６５１－２９９７（代）", size: 12, halign: :left)
      grid.text(9, 1, 1, "合計金額", bold: true, halign: :left)
      grid.text(9, 5, 6, "FAX　　　（０７８）６５１－２６２５", size: 12, halign: :left)
      grid.text(10, 2, 2, grand_total, size: 16, bold: true, halign: :center, number_format: "[$¥-411]#,##0")
      grid.line(10, 2, 2, :bottom)
      grid.text(11, 1, 1, "見積有効期限", halign: :left)
      grid.text(12, 2, 2, "３０日", halign: :center)
      grid.line(12, 2, 2, :bottom)

      grid.text(14, 1, 1, "納入場所（納入先）", halign: :left)
      grid.text(15, 2, 2, "御社御指定国内倉庫", halign: :center)
      grid.line(15, 2, 2, :bottom)
      [ [ 4, "運賃", "元" ], [ 5, "荷造費", "元" ], [ 6, "支払条件", "従来通り" ] ].each do |col, label, value|
        grid.text(14, col, col, label, halign: :center)
        grid.text(15, col, col, value, halign: :center)
        grid.line(15, col, col, :bottom)
      end
      grid.text(17, 1, 1, "納入期日", halign: :left)
      grid.text(18, 2, 2, "御社御下命後４日", halign: :center)
      grid.line(18, 2, 2, :bottom)
      grid.text(17, 3, 3, "備考", size: 8, halign: :center)
      grid.text(17, 4, 7, "　５万円以下の御注文に対しましては、梱包運賃３千円", size: 10, halign: :left)
      grid.text(18, 4, 7, "　申受けます。但し、消費税・特別運賃は別途申受けます。", size: 10, halign: :left)
      grid.line(18, 4, 7, :bottom)

      # 船名・型式・ENG.No.の枠
      grid.height(21, 21)
      [ [ 1, 2, "船名", @order.shipname ], [ 4, 5, "型式", @order.etype ], [ 6, 7, "ENG.No.", @order.engno ] ].each do |c1, c2, label, value|
        grid.text(23, c1, c1, label, size: 8, halign: :left)
        grid.text(24, c1, c2, value, size: 18, bold: true, halign: :center, valign: :center, number_format: "@")
        grid.box(23, c1, 24, c2, :thin)
      end
      grid.box(23, 3, 24, 3, :thin)

      build_table(grid, 26, FIRST_PAGE_ITEMS, page_items, close_table: false)
      # 合計(複数ページのときは1ページ目の小計)の二重枠
      grid.box(57, 5, 58, 6, :double)
      grid.text(58, 5, 5, last_page ? "合計" : "小計", halign: :right)
      grid.text(58, 6, 6, page_total, halign: :right, number_format: "#,##0")
      # E:Fの間の縦線(E57:E58の右、F57:F58の左)
      [ 57, 58 ].each do |row|
        grid.line(row, 5, 5, :right)
        grid.line(row, 6, 6, :left)
      end
      # 最終行(56行目)の下線。E:Fは合計の二重枠の上辺が兼ねる
      [ 1, 2, 3, 4, 7 ].each { |c| grid.line(56, c, c, :bottom) }
      # 合計の枠(E:F)の左右は表の縦線を続け、表の最下線は58行目に引く
      [ 1, 2, 3, 4, 7 ].each do |c|
        [ 57, 58 ].each do |row|
          grid.line(row, c, c, :left)
          grid.line(row, c, c, :right)
        end
        grid.line(58, c, c, :bottom)
      end
    end

    # 顧客(A3:会社名 御中、B4:部署名)と日付(F3)。旧ASPのA3・B4・F3
    def write_customer(grid)
      today = Date.current
      grid.text(3, 1, 4, "#{@adlist&.company} 御中", size: 14, bold: true, halign: :left)
      grid.text(3, 6, 6, "#{today.year}年#{today.month}月#{today.day}日", halign: :left)
      grid.text(4, 2, 4, @adlist&.section, halign: :left)
    end

    # --- 2ページ目以降 --------------------------------------------------------

    def build_continuation(grid, page_items, page_no:, page_total:, cumulative:, last_page:)
      grid.height(1, 6)
      grid.height(2, 21.9)
      grid.text(2, 5, 5, "No.", size: 12, bold: true, halign: :right)
      grid.text(2, 6, 6, @order.mno.to_s, size: 12, bold: true, halign: :left)
      grid.text(2, 7, 7, page_no, halign: :center)
      grid.height(3, 21.9)
      build_table(grid, 3, CONTINUATION_PAGE_ITEMS, page_items, close_table: false)

      # 54・55行目は明細の1件(2行1組)と同じ罫線・行の高さにそろえ、表の続きとして小計を載せる。
      # 小計: E54:G55の細い外枠の内側に、E54:F55の二重外枠(ラベルと値は下の55行目)
      last = 3 + CONTINUATION_PAGE_ITEMS * 2
      top = last + 1
      grid.height(top, 15)
      grid.height(top + 1, 15)
      (1..COLUMN_COUNT).each do |col|
        grid.line(top, col, col, :top)
        [ top, top + 1 ].each do |row|
          grid.line(row, col, col, :left)
          grid.line(row, col, col, :right)
        end
      end
      [ 1, 2, 3, 4, 7 ].each { |c| grid.line(top + 1, c, c, :bottom) }
      grid.box(top, 5, top + 1, 7, :thin)
      grid.box(top, 5, top + 1, 6, :double)
      grid.text(top + 1, 5, 5, "小計", halign: :right)
      grid.text(top + 1, 6, 6, page_total, halign: :right, number_format: "#,##0")

      # 累計(最終ページは合計): E56:F56の太枠
      grid.height(last + 3, 21.9)
      grid.box(last + 3, 5, last + 3, 6, :medium)
      grid.text(last + 3, 5, 5, last_page ? "合計" : "累計", halign: :right)
      grid.text(last + 3, 6, 6, cumulative, halign: :right, number_format: "#,##0")
    end

    # --- 明細表(1・2ページ目以降共通) -----------------------------------------

    # header_rowを見出し行として、その下に1件2行1組でcapacity件分の枠を作り、items(空きは枠だけ)を書く。
    # close_tableがtrueなら表の最下線も引く(1ページ目は合計の枠の下に引くので false)。
    def build_table(grid, header_row, capacity, items, close_table:)
      header = [ [ 1, "No.　" ], [ 2, "品名・仕様" ], [ 3, "数量" ], [ 4, "単位" ], [ 5, "単価" ], [ 6, "金額" ], [ 7, "総重量/kg" ] ]
      header.each do |col, label|
        grid.text(header_row, col, col, label, size: (col == 7 ? 8 : 11), halign: :center, valign: :center, fill: "FFC0C0C0")
        grid.box(header_row, col, header_row, col, :thin)
      end

      capacity.times do |i|
        top = header_row + 1 + i * 2
        grid.height(top, 15)
        grid.height(top + 1, 15)
        (1..COLUMN_COUNT).each do |col|
          grid.line(top, col, col, :top)
          [ top, top + 1 ].each do |row|
            grid.line(row, col, col, :left)
            grid.line(row, col, col, :right)
          end
        end
        fill_item(grid, top, items[i]) if items[i]
      end
      grid.line(header_row + capacity * 2, 1, COLUMN_COUNT, :bottom) if close_table
    end

    # 1件分(top=上段の行、top+1=下段の行)を書く。数量0の明細は旧ASPどおり空欄のまま(番号も出さない)
    def fill_item(grid, top, item)
      return if item[:skip]

      bottom = top + 1
      grid.text(top, 1, 1, item[:no], halign: :center, valign: :center)
      grid.text(top, 2, 2, item[:head], halign: :left)
      grid.text(bottom, 2, 2, item[:name], halign: :left)
      grid.text(bottom, 3, 3, item[:qty], halign: :center)
      # 単位欄: 上段の数字(10など)は左寄せ、文字(SETなど)と下段の「袋」は右寄せ
      grid.text(top, 4, 4, item[:sel_unit], halign: (SalesUnit.numeric?(item[:sel_unit]) ? :left : :right))
      grid.text(bottom, 4, 4, item[:unit_name], halign: :right)
      grid.text(bottom, 5, 5, item[:price], halign: :right, number_format: "#,##0")
      grid.text(bottom, 6, 6, item[:amount_text], halign: :right, number_format: "#,##0")
      grid.text(bottom, 7, 7, item[:weight], halign: :center)
    end

    # --- 明細データ ------------------------------------------------------------

    # 旧ASPは数量0の明細を飛ばしつつ、番号(j)と行の位置は進める。ここでも枠(スロット)は残して中身だけ空にする。
    def build_items
      @items.each_with_index.map do |item, idx|
        next({ skip: true, amount: 0 }) unless item.qty.to_f.positive?

        build_item(item, idx + 1)
      end
    end

    def build_item(item, no)
      pricing = ItemPricing.for(item)
      sel = item.unit.to_s.strip

      {
        no: no,
        head: head_text(item),
        name: item.name,
        qty: pricing.qty,
        # バラ売りのときは販売単位を出さない。数字の販売単位(例: 10)は10個で1袋なので「袋」を添える
        sel_unit: (SalesUnit.sel_unit(sel) unless pricing.bulk),
        unit_name: (SalesUnit.name(sel) unless pricing.bulk),
        price: (pricing.price.positive? ? pricing.price : "後報"),
        amount: pricing.amount,
        amount_text: (pricing.amount.positive? ? pricing.amount : "後報"),
        weight: weight_text(item)
      }
    end

    # 上段の「部品番号 備考 ItemNo」。備考とItemNoが同じならItemNoは出さない。部品番号なし見積では部品番号を出さない。
    def head_text(item)
      itemno = item.itemno.to_s.strip
      itemno = nil if DEFAULT_ITEMNOS.include?(itemno) || itemno == item.info.to_s.strip
      [ (item.code if show_part_no?), item.info, itemno ].compact_blank.join(" ")
    end

    def weight_text(item)
      weight = item.totalweight.to_f
      return nil unless weight.positive? && weight != UNKNOWN_WEIGHT

      weight.round(3).to_s.sub(/\.0\z/, "")
    end

    def paginate(items)
      return [ items ] if items.size <= FIRST_PAGE_ITEMS

      pages = [ items.first(FIRST_PAGE_ITEMS) ]
      items[FIRST_PAGE_ITEMS..].each_slice(CONTINUATION_PAGE_ITEMS) { |chunk| pages << chunk }
      pages
    end

    # --- 承認の枠(図形) -----------------------------------------------------------

    # 1ページ目右上の承認欄(F列の左右半分ずつの2つの枠)。旧様式では図形で、10〜13行目あたりに置いてある。
    # F列は18.2文字≒133pxなので、半分(66px)を境に2つの長方形を置く。
    STAMP_BOX_COLUMN = 5 # F列(0始まり)
    STAMP_BOX_HALF_EMU = 66 * 9_525
    STAMP_BOX_MARGIN_EMU = 5 * 9_525

    def inject_stamp_boxes(path)
      ShapePatchedPackage.inject_drawing(path, stamp_boxes_drawing_xml, rel_id: "rIdStampBoxes")
    end

    def stamp_boxes_drawing_xml
      left = STAMP_BOX_MARGIN_EMU
      mid = STAMP_BOX_HALF_EMU
      right = STAMP_BOX_HALF_EMU * 2 - STAMP_BOX_MARGIN_EMU
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
        #{stamp_box_anchor_xml(1, "StampBoxLeft", left, mid)}
        #{stamp_box_anchor_xml(2, "StampBoxRight", mid, right)}
        </xdr:wsDr>
      XML
    end

    # 10行目の少し下(行index 9、5pt)から13行目の少し下(行index 12、8pt)までの長方形(線のみ)
    def stamp_box_anchor_xml(id, name, from_off, to_off)
      <<~XML
        <xdr:twoCellAnchor>
        <xdr:from><xdr:col>#{STAMP_BOX_COLUMN}</xdr:col><xdr:colOff>#{from_off}</xdr:colOff><xdr:row>9</xdr:row><xdr:rowOff>63500</xdr:rowOff></xdr:from>
        <xdr:to><xdr:col>#{STAMP_BOX_COLUMN}</xdr:col><xdr:colOff>#{to_off}</xdr:colOff><xdr:row>12</xdr:row><xdr:rowOff>101600</xdr:rowOff></xdr:to>
        <xdr:sp macro="" textlink="">
        <xdr:nvSpPr><xdr:cNvPr id="#{id}" name="#{name}"/><xdr:cNvSpPr/></xdr:nvSpPr>
        <xdr:spPr>
        <a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        <a:noFill/>
        <a:ln w="9525"><a:solidFill><a:srgbClr val="000000"/></a:solidFill></a:ln>
        </xdr:spPr>
        </xdr:sp>
        <xdr:clientData/>
        </xdr:twoCellAnchor>
      XML
    end
  end
end
