# frozen_string_literal: true

require "delegate"
require "zip"
require "tempfile"
require "stringio"

module XlsxReports
  # 請求書(seikyu.xls / asp/A4pseikyu.asp相当)。
  # Order 1件+その明細(Orderpart)からxlsxを生成する。
  #
  # ページ制御・小計/累計/値引き/消費税/銀行フッタのロジックは
  # 旧asp/A4pseikyu.asp を移植したもの(コメント中のコード行番号は同ファイル基準)。
  class SeikyuReport < TabularReport
    COMPANY_NAME = "神戸エンジンサービス株式会社"
    COMPANY_ADDRESS = "神戸市長田区東尻池町9丁目1番12号"
    COMPANY_TEL = "電話神戸(078)651-2997(代)"
    COMPANY_FAX = "FAX　　　(078)651-2625"

    BANK_INFO_ROW1 = [ "三井住友銀行兵庫支店　当座No.2117831", "三菱UFJ銀行神戸支店　普通 No.2445381" ].freeze
    BANK_INFO_ROW2 = [ "T9-1400-0101-1890", "みずほ銀行神戸支店　当座 No.0122296" ].freeze

    DEFAULT_TAX_RATE = 10 # % (旧ASPはSession値、デフォルト8%だったが現行税率に合わせる)

    # 旧ASP: p1max=22(表紙は1〜21件、22件目から次紙) / pmax=26(次紙以降は26件ずつ)
    FIRST_PAGE_ITEMS = 21
    CONTINUATION_PAGE_ITEMS = 26

    def initialize(order, tax_rate: DEFAULT_TAX_RATE)
      @order = order
      # adlist_idはadlistsのid ではなく no列を指すという既存実装(orders/show.html.haml)の慣習に合わせる
      @adlist = Adlist.find_by(no: order.adlist_id.to_s)
      @orderparts = Orderpart.where(mno: order.mno).reorder(:sno)
      @tax_rate = tax_rate
      @bracket_anchor_rows = nil
      @dept_label = nil
    end

    def filename
      "seikyu_#{@order.mno}.xlsx"
    end

    # 「お届け先」欄の丸カッコ、及び部署名(C5セル内で「殿」と別寄せにするための
    # 透明テキストボックス重ね)はcaxlsxに高レベルAPIが無いため、生成済みのxlsxに
    # 図形を後からXMLで挿入する。(caxlsx自体には手を入れず、Packageをラップして
    # serialize/to_streamの出力だけ加工する)
    def generate
      package = super
      return package unless @bracket_anchor_rows

      BracketShapePatchedPackage.new(package, method(:inject_extra_shapes))
    end

    private

    def inject_extra_shapes(path)
      Zip::File.open(path) do |zip|
        zip.get_output_stream("xl/drawings/drawing1.xml") { |f| f.write(extra_shapes_drawing_xml) }

        rels_path = "xl/worksheets/_rels/sheet1.xml.rels"
        rels_xml = if zip.find_entry(rels_path)
          zip.read(rels_path)
        else
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>'
        end
        rel_id = "rIdBracketDrawing"
        rels_xml = rels_xml.sub(
          "</Relationships>",
          %(<Relationship Id="#{rel_id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/></Relationships>)
        )
        zip.get_output_stream(rels_path) { |f| f.write(rels_xml) }

        sheet_xml = zip.read("xl/worksheets/sheet1.xml").sub("</worksheet>", %(<drawing r:id="#{rel_id}"/></worksheet>))
        zip.get_output_stream("xl/worksheets/sheet1.xml") { |f| f.write(sheet_xml) }

        ct_path = "[Content_Types].xml"
        ct_xml = zip.read(ct_path)
        unless ct_xml.include?("/xl/drawings/drawing1.xml")
          ct_xml = ct_xml.sub(
            "</Types>",
            %(<Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/></Types>)
          )
          zip.get_output_stream(ct_path) { |f| f.write(ct_xml) }
        end
      end
    end

    # 図形の太さ(幅)。C列は品名列で幅30と非常に広いため、列幅いっぱいに合わせると
    # 横長(列跨ぎ)に見えてしまう。列幅に関係なく固定の太さ(10pt相当)にする。
    BRACKET_WIDTH_EMU = 127_000

    def extra_shapes_drawing_xml
      from_row, to_row = @bracket_anchor_rows
      dept_shape = if @dept_label
        text_box_anchor_xml(3, row: @dept_label[:row], from_col: 1, to_col: 3, text: @dept_label[:text], name: "DeptLabel", algn: "ctr")
      else
        ""
      end

      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
        #{bracket_shape_anchor_xml(1, col: 0, from_row: from_row, to_row: to_row, name: "LeftBracket", prst: "leftBracket")}
        #{bracket_shape_anchor_xml(2, col: 3, from_row: from_row, to_row: to_row, name: "RightBracket", prst: "rightBracket")}
        #{dept_shape}
        </xdr:wsDr>
      XML
    end

    # from_col〜to_col(列境界)・row1行分のセル範囲にちょうど重なる透明なテキストボックスを配置する。
    # B:C結合セルに「部署名(中央寄せ)」を、C5セル自体の値である「殿」(右寄せ)と
    # はみ出しなく別々の寄せで共存させるために使う(セルの罫線・背景は透明のまま、文字だけ重ねる)。
    def text_box_anchor_xml(id, row:, from_col:, to_col:, text:, name:, algn:)
      <<~XML
        <xdr:twoCellAnchor>
        <xdr:from><xdr:col>#{from_col}</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>#{row}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>
        <xdr:to><xdr:col>#{to_col}</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>#{row + 1}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>
        <xdr:sp macro="" textlink="">
        <xdr:nvSpPr><xdr:cNvPr id="#{id}" name="#{name}"/><xdr:cNvSpPr txBox="1"/></xdr:nvSpPr>
        <xdr:spPr>
        <a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        <a:noFill/>
        <a:ln><a:noFill/></a:ln>
        </xdr:spPr>
        <xdr:txBody>
        <a:bodyPr wrap="none" lIns="0" tIns="0" rIns="0" bIns="0" anchor="ctr"/>
        <a:lstStyle/>
        <a:p><a:pPr algn="#{algn}"/><a:r><a:rPr lang="ja-JP" sz="1100"/><a:t>#{xml_escape(text)}</a:t></a:r></a:p>
        </xdr:txBody>
        </xdr:sp>
        <xdr:clientData/>
        </xdr:twoCellAnchor>
      XML
    end

    def xml_escape(str)
      str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end

    # col(0始まり)の左端を起点に、固定の太さ(BRACKET_WIDTH_EMU)・from_row〜to_rowの高さで図形を配置する。
    # 右カッコは「C列の右端」に置きたいが、C列自体の実際のピクセル幅は環境(フォント)依存で
    # 正確に計算できないため、代わりに常に厳密な位置が確定するD列(col:3)の左端を起点にする。
    # D列の左端 = C列の右端は列幅に関わらず必ず一致するので、見た目はC列右寄せになる。
    def bracket_shape_anchor_xml(id, col:, from_row:, to_row:, name:, prst:)
      <<~XML
        <xdr:twoCellAnchor>
        <xdr:from><xdr:col>#{col}</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>#{from_row}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>
        <xdr:to><xdr:col>#{col}</xdr:col><xdr:colOff>#{BRACKET_WIDTH_EMU}</xdr:colOff><xdr:row>#{to_row}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>
        <xdr:sp macro="" textlink="">
        <xdr:nvSpPr><xdr:cNvPr id="#{id}" name="#{name}"/><xdr:cNvSpPr/></xdr:nvSpPr>
        <xdr:spPr>
        <a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm>
        <a:prstGeom prst="#{prst}"><a:avLst><a:gd name="adj" fmla="val 40000"/></a:avLst></a:prstGeom>
        <a:noFill/>
        <a:ln w="19050"><a:solidFill><a:srgbClr val="000000"/></a:solidFill></a:ln>
        </xdr:spPr>
        <xdr:txBody><a:bodyPr/><a:lstStyle/><a:p/></xdr:txBody>
        </xdr:sp>
        <xdr:clientData/>
        </xdr:twoCellAnchor>
      XML
    end

    # 直前にadd_rowした行の高さを指定する(pt単位)。1ページに収まる行数を稼ぐため全体的に詰めている。
    def set_last_row_height(sheet, height)
      sheet.rows[sheet.rows.size - 1].height = height
    end

    # 列幅の定義にのみ使う(明細行はcolumnsを介さず2行1組で個別に組み立てるため)
    def columns
      [
        Column.new(key: :no, width: 5),
        Column.new(key: :partno, width: 14),
        Column.new(key: :name, width: 30),
        Column.new(key: :qty, width: 6),
        Column.new(key: :unit, width: 6),
        Column.new(key: :price, width: 10),
        Column.new(key: :amount, width: 16)
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
          # 幅は必ず1ページに収め、高さは制限しない。
          # fit_to(width:1, height:1)で両方縛ると、明細件数(=高さ)が多いページほど
          # 高さ側の制約で強く縮小されてしまい、ページごとに横倍率がバラつく
          # (件数が少ない最終ページだけ余白なく広く見える)ため、幅だけを固定する。
          sheet.page_setup.fit_to_width = 1
          sheet.page_setup.fit_to_height = 0
          # 用紙サイズを明示しないと環境によってLetter等(A4より短い)になり、
          # 高さの計算が合わなくなることがあるため明示的にA4を指定する
          sheet.page_setup.paper_size = 9
          # 左は二穴パンチの余裕を見て広め、右は詰め気味にする(左右非対称)
          sheet.page_margins.set(top: 0.2, bottom: 0.2, left: 1.0, right: 0.15, header: 0, footer: 0)
          # 明細が少ないページは下側だけ余白が余って見えるため、上下の余りを均等に配分する。
          # ただし最終ページは、通常の帳票の最後のページと同じく上詰めのままにする
          # (最終ページだけ短いのに中央寄せだと、かえって不自然に見えるため)。
          sheet.print_options.vertical_centered = true unless is_last

          if page_no == 1
            build_cover_header(sheet)
          else
            build_continuation_header(sheet, page_no)
          end

          build_two_row_items(sheet, page_items)

          page_subtotal = page_items.sum { |item| item[:amount] }
          cumulative += page_subtotal
          build_footer(sheet, page_no: page_no, total_pages: pages.size,
                        page_subtotal: page_subtotal, cumulative: cumulative, is_last: is_last)

          set_column_widths(sheet, *columns.map(&:width))
        end
      end
    end

    def build_cover_header(sheet)
      sheet.add_row([ nil, nil, nil, nil, "No.", @order.mno, "1" ],
                     style: [ nil, nil, nil, nil, style(sheet, halign: :right), style(sheet, halign: :center), style(sheet, halign: :right) ])
      set_last_row_height(sheet, 14)
      title_style = style(sheet, size: 16, bold: true, halign: :center, bottom: :thin)
      sheet.add_row([ nil, nil, "請　求　書", nil, Date.current.strftime("%Y年%-m月%-d日") ],
                     style: [ nil, nil, title_style, title_style, style(sheet, halign: :right) ])
      set_last_row_height(sheet, 20)
      date_row = sheet.rows.size
      sheet.merge_cells("C#{date_row}:D#{date_row}")
      sheet.merge_cells("E#{date_row}:G#{date_row}")
      sheet.add_row([ nil, nil, nil, nil, "(出荷日　#{shipping_date_label})" ],
                     style: [ nil, nil, nil, nil, style(sheet, halign: :right, size: 9) ])
      set_last_row_height(sheet, 13)
      shipping_row = sheet.rows.size
      sheet.merge_cells("E#{shipping_row}:G#{shipping_row}")
      company_style = style(sheet, size: 14, bold: true, halign: :left)
      sheet.add_row([ nil, @adlist&.company, nil, "株式会社IHI原動機　代理店" ],
                     style: [ nil, company_style, company_style, style(sheet, halign: :center) ])
      set_last_row_height(sheet, 22)
      agent_row = sheet.rows.size
      sheet.merge_cells("B#{agent_row}:C#{agent_row}")
      sheet.merge_cells("D#{agent_row}:G#{agent_row}")
      # 「殿」はC8と揃えてC5セル自体の値として右寄せにする。部署名はB列にははみ出さず
      # C5セルの中だけに収めたいので、透明なテキストボックス図形を同じC5位置に重ねて
      # 左寄せで表示する(セルの値と図形は別レイヤーなので、はみ出しなく共存できる)。
      tono_style = style(sheet, bottom: :thick, halign: :right)
      sheet.add_row([ nil, nil, "殿", nil, COMPANY_NAME ],
                     style: [ nil, style(sheet, bottom: :thick), tono_style, nil, style(sheet, size: 12, bold: true) ])
      set_last_row_height(sheet, 22)
      dono_row = sheet.rows.size
      @dept_label = { row: dono_row - 1, text: @adlist.section } if @adlist&.section.present?

      # 「お届け先」欄をA列(左カッコ)/C列(右カッコ)の3行(A6:A8 / C6:C8)に
      # 跨る丸カッコで挟む。セル結合+文字では罫線や文字ボックスの制約で
      # 角ばったり期待の高さまで広がらなかったりするため、実際のExcel図形
      # (leftBracket/rightBracket、角丸)をセル位置に合わせて後から重ねる
      # (#generate参照、@bracket_anchor_rowsで座標を渡す)。
      sheet.add_row([ "お届け先", nil, nil, nil, COMPANY_ADDRESS ],
                     style: [ style(sheet, halign: :left), nil, nil, nil, nil ])
      set_last_row_height(sheet, 14)
      atesaki_top_row = sheet.rows.size
      sheet.add_row([ nil, nil, nil, nil, COMPANY_TEL ])
      set_last_row_height(sheet, 13)
      sheet.add_row([ nil, nil, "殿", nil, COMPANY_FAX ],
                     style: [ nil, nil, style(sheet, halign: :right), nil, nil ])
      set_last_row_height(sheet, 13)
      atesaki_bottom_row = sheet.rows.size
      @bracket_anchor_rows = [ atesaki_top_row - 1, atesaki_bottom_row ]

      # 注番/船名/型式(船籍)/ENG.No.は値が長くなりがちなので、7列分をA:B/C/D/E:F/Gに割り振る。
      # D列は船籍のラベル・値専用。ラベル行は全列左寄せ、値の行は全列中央寄せ。
      # ラベル行(新9行目)と値の行(新10行目)の間の線が出ないよう、
      # ラベル行は下辺なし、値の行は上辺なしにする(外枠の他3辺は残す)
      info_header_style = style(sheet, top: :thin, left: :thin, right: :thin, halign: :left, size: 8)
      info_value_style = style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :center, valign: :center, bold: true, size: 11)

      sheet.add_row([ "注番", nil, "船名", "船籍", "型式", nil, "ENG.No." ], style: Array.new(7) { info_header_style })
      set_last_row_height(sheet, 13)
      header_row = sheet.rows.size
      sheet.add_row([ @order.ono, nil, @order.shipname, @order.country, @order.etype, nil, @order.engno ],
                     style: Array.new(7) { info_value_style })
      set_last_row_height(sheet, 26)
      value_row = sheet.rows.size
      sheet.add_row([])
      set_last_row_height(sheet, 2)

      [ header_row, value_row ].each do |row_no|
        sheet.merge_cells("A#{row_no}:B#{row_no}")
        sheet.merge_cells("E#{row_no}:F#{row_no}")
      end
    end

    def build_continuation_header(sheet, page_no)
      sheet.add_row([ "請求書", nil, nil, nil, "No.", @order.mno, page_no.to_s ],
                     style: [ style(sheet, size: 12, bold: true), nil, nil, nil,
                             style(sheet, halign: :right), style(sheet, halign: :center), style(sheet, halign: :right) ])
      set_last_row_height(sheet, 16)
      sheet.add_row([])
      set_last_row_height(sheet, 6)
    end

    def shipping_date_label
      date = @order.syuday || @order.rdate
      date ? date.strftime("%Y年%-m月%-d日") : Date.current.strftime("%Y年%-m月%-d日")
    end

    # 1明細=2行(1行目:ItemNo/備考、2行目:品番/品名/数量/単位/単価/金額)。旧ASPの列構成に合わせている。
    def build_two_row_items(sheet, items)
      header_style = style(sheet, border: :thin, bold: true, halign: :center, valign: :center, fill: "FFC0C0C0")
      sheet.add_row([ "No.", "ItemNo/品番", "備考/品名・仕様", "数量", "単位", "単価", "金額" ], style: Array.new(7) { header_style })
      set_last_row_height(sheet, 14)

      items.each do |item|
        row1_default = style(sheet, top: :thin, left: :thin, right: :thin)
        row2_default = style(sheet, bottom: :thin, left: :thin, right: :thin)

        sheet.add_row(
          [ item[:no], item[:itemno], item[:info], nil, nil, nil, nil ],
          style: Array.new(7) { row1_default }
        )
        set_last_row_height(sheet, 13)
        sheet.add_row(
          [ nil, item[:partno], item[:name], item[:qty], item[:unit], item[:price], item[:amount] ],
          style: [
            row2_default,
            row2_default,
            row2_default,
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right),
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :center),
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right, number_format: "#,##0"),
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right, number_format: "#,##0")
          ]
        )
        set_last_row_height(sheet, 13)
      end
    end

    def build_items
      @orderparts.map do |orderpart|
        # orders/show.html.haml と同じく、Part台帳になければKepart(KE部品)台帳も見る
        part = Part.find_by(pcode: orderpart.partno) || Kepart.find_by(pcode: orderpart.partno)
        amount = (orderpart.irate.to_f * orderpart.qty.to_f * orderpart.unitpd.to_f).round
        {
          no: orderpart.sno,
          itemno: orderpart.itemno,
          info: orderpart.info,
          partno: orderpart.partno,
          name: part&.jname,
          qty: orderpart.qty,
          # orderpart.unitはほぼ未入力のため、品名と同じくPart/Kepart台帳のsel_unitを補完的に見る
          unit: orderpart.unit.presence || part&.sel_unit,
          price: orderpart.unitpd,
          amount: amount
        }
      end
    end

    # 明細行(1レコード=2行)と行数を合わせるため、小計/累計/値引/消費税/総合計も
    # 2行1組にする(1行目は空・上辺のみ、2行目にラベルと値・下辺のみ。明細行同様、
    # 1組の中間には罫線を引かない)。F:G列は2行分の外周(上下左右)を常に二重罫線で囲むが、
    # A〜E列側の外枠は総合計含め常に一重。F/G間の内側縦線は常に一重、2行の間には横線を引かない。
    # note指定時は2行目(ラベル・値のある行、小計と同じ行)のC列に注記(「次葉に続く」等)を表示する。
    def add_summary_row(sheet, label, value, note: nil)
      fg_outer = :double
      row1_style = style(sheet, top: :thin, left: :thin, right: :thin)
      row2_style = style(sheet, bottom: :thin, left: :thin, right: :thin)
      f_row1_style = style(sheet, top: fg_outer, left: fg_outer, right: :thin)
      g_row1_style = style(sheet, top: fg_outer, left: :thin, right: fg_outer)
      label_style = style(sheet, bottom: fg_outer, left: fg_outer, right: :thin, halign: :right)
      value_style = style(sheet, bottom: fg_outer, left: :thin, right: fg_outer, halign: :right, number_format: "#,##0")

      sheet.add_row(Array.new(7),
                     style: [ row1_style, row1_style, row1_style, row1_style, row1_style, f_row1_style, g_row1_style ])
      set_last_row_height(sheet, 13)
      row2_values = [ nil, nil, nil, nil, nil, label, value ]
      row2_values[2] = note if note
      sheet.add_row(row2_values,
                     style: [ row2_style, row2_style, row2_style, row2_style, row2_style, label_style, value_style ])
      set_last_row_height(sheet, 13)
    end

    def build_footer(sheet, page_no:, total_pages:, page_subtotal:, cumulative:, is_last:)
      unless is_last
        add_summary_row(sheet, "小計", page_subtotal, note: "次葉に続く")
        add_summary_row(sheet, "累計", cumulative) if page_no > 1
        return
      end

      add_summary_row(sheet, "小計", page_subtotal)
      add_summary_row(sheet, "累計", cumulative) if total_pages > 1

      nebiki = @order.nebiki.to_i
      base = cumulative
      if nebiki.positive?
        after_discount = base - nebiki
        add_summary_row(sheet, "値引", -nebiki)
        add_summary_row(sheet, "値引後合計", after_discount)
        base = after_discount
      end

      tax = (base * @tax_rate / 100.0).round
      add_summary_row(sheet, "消費税(#{@tax_rate}%)", tax)
      add_summary_row(sheet, "総合計", base + tax)

      build_bank_footer(sheet)
    end

    # B列に「取引銀行」「登録番号」ラベル(右寄せ)、1行目はC:D/E:Gに2行分の銀行情報、
    # 2行目はC列(単独)に登録番号・E:Gに銀行情報、という2行構成。
    def build_bank_footer(sheet)
      label_style = style(sheet, size: 9, halign: :right)
      value_style = style(sheet, size: 9)

      sheet.add_row([ nil, "取引銀行", BANK_INFO_ROW1[0], nil, BANK_INFO_ROW1[1], nil, nil ],
                     style: [ nil, label_style, value_style, nil, value_style, nil, nil ])
      set_last_row_height(sheet, 13)
      row1 = sheet.rows.size
      sheet.merge_cells("C#{row1}:D#{row1}")
      sheet.merge_cells("E#{row1}:G#{row1}")

      sheet.add_row([ nil, "登録番号", BANK_INFO_ROW2[0], nil, BANK_INFO_ROW2[1], nil, nil ],
                     style: [ nil, label_style, value_style, nil, value_style, nil, nil ])
      set_last_row_height(sheet, 13)
      row2 = sheet.rows.size
      sheet.merge_cells("E#{row2}:G#{row2}")
    end
  end

  # Axlsx::Packageをラップし、serialize/to_streamの出力(=完成したxlsxのzip)に対して
  # 後から任意のXML加工を行うためのデコレータ。SeikyuReport#generateから使う。
  class BracketShapePatchedPackage < SimpleDelegator
    def initialize(package, patcher)
      super(package)
      @patcher = patcher
    end

    def serialize(path, *args, **kwargs)
      result = __getobj__.serialize(path, *args, **kwargs)
      @patcher.call(path)
      result
    end

    def to_stream(*args, **kwargs)
      Tempfile.create([ "xlsx_bracket_patch", ".xlsx" ]) do |tmp|
        tmp.binmode
        tmp.write(__getobj__.to_stream(*args, **kwargs).read)
        tmp.flush
        @patcher.call(tmp.path)
        tmp.rewind
        StringIO.new(File.binread(tmp.path))
      end
    end
  end
end
