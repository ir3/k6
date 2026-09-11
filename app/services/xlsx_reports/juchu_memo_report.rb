# frozen_string_literal: true

require "delegate"
require "zip"
require "tempfile"
require "stringio"

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

    # caxlsx(4.5.0時点)はPageSetupのblackAndWhite属性に対応していないため、
    # SeikyuReportと同じ手法(生成済みxlsxをXMLとして後から加工)で挿入する。
    def generate
      BlackAndWhitePatchedPackage.new(super)
    end

    private

    # 列幅の定義にのみ使う(明細行はcolumnsを介さず2行1組で個別に組み立てるため)。
    # 先頭のmarginは左端の余白用の空列(A列)。明細2行分の高さ(16pt×2=32pt)より
    # 幅を広くしたいので6にしている(3のままでは2行の高さより狭かった)。
    def columns
      [
        Column.new(key: :margin, width: 6),
        Column.new(key: :code, width: 16),
        Column.new(key: :name, width: 34),
        Column.new(key: :qty, width: 7),
        Column.new(key: :unit, width: 7),
        Column.new(key: :blank, width: 7), # 明細2行分の高さ(20pt×2=40pt)相当の幅にしている
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
          sheet.page_setup.paper_size = 9 # A4(OOXML ST_PaperSizeの9)。白黒印刷指定は#generateでXMLへ後から追記する
          sheet.page_margins.set(top: 0.4, bottom: 0.3, left: 0.6, right: 0.3, header: 0, footer: 0)

          build_header(sheet, page_no)
          build_two_row_items(sheet, page_items)

          page_subtotal = page_items.sum { |item| item[:amount] }
          cumulative += page_subtotal
          build_footer(sheet, total_pages: pages.size, page_subtotal: page_subtotal, cumulative: cumulative)

          set_column_widths(sheet, *columns.map(&:width))
        end
      end
    end

    def build_header(sheet, page_no)
      title_style = style(sheet, size: 16, bold: true, halign: :center)
      sheet.add_row([ nil, nil, nil, nil, nil, nil, nil, nil, page_no.to_s ],
                     style: [ nil, nil, nil, nil, nil, nil, nil, style(sheet, top: :thin), style(sheet, top: :thin, halign: :right) ])
      set_last_row_height(sheet, 13)
      sheet.add_row([ nil, nil, "受注メモ", nil, nil, nil, nil, "No.", @order.mno ],
                     style: [ nil, nil, title_style, title_style, title_style, nil, nil, style(sheet, halign: :right), style(sheet, halign: :right) ])
      sheet.merge_cells("C#{sheet.rows.size}:E#{sheet.rows.size}")
      set_last_row_height(sheet, 22)

      box_label = style(sheet, border: :thin, halign: :left, size: 8)
      box_value = style(sheet, border: :thin, halign: :center)
      # 外枠(A列)は右辺を持たず、B列は左辺を持たない組み合わせにすることで、
      # A/B間に線を引かず、箱全体の左端(A列の左辺)だけに縦線が来るようにする。
      edge_label = style(sheet, top: :thin, left: :thin, halign: :left, size: 8)
      i_right_line = style(sheet, right: :thin)
      # ラベル行の下線・値行の上線を引かず、ラベルと値が1つの続いた枠に見えるようにする
      b_no_left_no_bottom = style(sheet, top: :thin, right: :thin)
      value_no_top_no_left = style(sheet, right: :thin, bottom: :thin, halign: :center)

      # 客先No.(A3ラベルのみ、値は非表示)、型式のラベル(A5)/値(A6:B6)、
      # 船籍のラベル(F5)/値(G6)、E/#のラベル(A7)/値(A8:B8)は、それぞれラベル行の
      # 下線・値行の上線を引かず1つの続いた枠に見えるようにする
      # (期限H3:I3・適用H5は自己完結した箱のまま)。期限はラベル(H3)/値(I4)も1行ずらす
      sheet.add_row([ "客先No.", nil, @adlist&.company, nil, nil, nil, nil, "期限", nil ],
                     style: [ style(sheet, top: :thin, left: :thin, halign: :left, valign: :top, size: 8), b_no_left_no_bottom,
                             style(sheet, top: :thin, left: :thin, halign: :left, size: 20),
                             style(sheet, top: :thin), style(sheet, top: :thin), style(sheet, top: :thin),
                             style(sheet, top: :thin, right: :thin),
                             style(sheet, top: :thin, left: :thin, halign: :left, valign: :top, size: 8),
                             style(sheet, top: :thin, right: :thin) ])
      set_last_row_height(sheet, 28)
      row = sheet.rows.size
      sheet.merge_cells("C#{row}:F#{row}")

      # 客先No.の値(B4)は表示不要、船名(旧C4)は6行目(C6)へ移した。C〜Gは部署名を結合・中央寄せで表示
      sheet.add_row([ nil, nil, @adlist&.section, nil, nil, nil, nil, nil, @order.rdate&.strftime("%Y/%m/%d") ],
                     style: [ style(sheet, left: :thin, bottom: :thin), value_no_top_no_left,
                             style(sheet, bottom: :thin, halign: :center), style(sheet, bottom: :thin), style(sheet, bottom: :thin),
                             style(sheet, bottom: :thin), style(sheet, right: :thin, bottom: :thin),
                             style(sheet, left: :thin, bottom: :thin), value_no_top_no_left ])
      set_last_row_height(sheet, 26)
      row = sheet.rows.size
      sheet.merge_cells("C#{row}:G#{row}")

      # 型式(A5左寄せ/A6:B6結合中央寄せ)・船名(C5ラベル/C6:E6結合の値)・船籍(F5/G6、
      # F/G間の線も消去)・適用(H5、下線と右側の縦線を消去)。I5の上には横罫線を追加する。
      sheet.add_row([ "型式", nil, "船名", nil, nil, "船籍", nil, "適用", nil ],
                     style: [ edge_label, b_no_left_no_bottom,
                             style(sheet, top: :thin, left: :thin, halign: :left, size: 8),
                             style(sheet, top: :thin), style(sheet, top: :thin, right: :thin),
                             style(sheet, top: :thin, left: :thin, halign: :left, size: 8),
                             style(sheet, top: :thin, right: :thin),
                             style(sheet, top: :thin, left: :thin, halign: :left, size: 8),
                             style(sheet, top: :thin, right: :thin) ])
      set_last_row_height(sheet, 14)

      # C〜Hの下線は7行目の上線消去と対になるよう、こちらも消す
      no_border = style(sheet)
      sheet.add_row([ @order.etype, nil, @order.shipname, nil, nil, nil, @order.country, nil, nil ],
                     style: [ style(sheet, left: :thin, bottom: :thin, halign: :center), value_no_top_no_left,
                             style(sheet, left: :thin, halign: :center, size: 18), no_border, style(sheet, right: :thin),
                             style(sheet, left: :thin), style(sheet, right: :thin, halign: :center),
                             style(sheet, left: :thin, halign: :center), i_right_line ])
      set_last_row_height(sheet, 26)
      row = sheet.rows.size
      sheet.merge_cells("A#{row}:B#{row}")
      sheet.merge_cells("C#{row}:E#{row}")

      # E/#はラベル(A7)/値(A8:B8、結合セルの先頭であるA8に値を入れる)を6行目の下に追加。
      # 型式と同じラベル/値パターン。C〜Hは空の仕切り列。
      # D列は罫線なし・G列は左辺なし・H列は右辺なしにするため、隣接セル側の対応する辺も
      # 一緒に消さないと線が残ってしまう(C列の右辺・E列の左辺・F列の右辺を合わせて消去)。
      # 7行目の下線・8行目の上線も、お互いに消さないと境界線が残るため両方消す。
      row7_c = style(sheet, left: :thin)
      row7_e = style(sheet, right: :thin)
      row7_f = style(sheet, left: :thin)
      row8_c = style(sheet, bottom: :thin, left: :thin)
      row8_e = style(sheet, bottom: :thin, right: :thin)
      row8_f = style(sheet, bottom: :thin, left: :thin)
      row7_g = style(sheet, right: :thin)
      row8_g = style(sheet, bottom: :thin, right: :thin)
      row7_h = style(sheet, left: :thin)
      row8_h = style(sheet, bottom: :thin, left: :thin)

      sheet.add_row([ "E/#", nil, nil, nil, nil, nil, nil, nil, nil ],
                     style: [ edge_label, b_no_left_no_bottom, row7_c, no_border, row7_e, row7_f, row7_g, row7_h, i_right_line ])
      set_last_row_height(sheet, 14)

      sheet.add_row([ @order.engno, nil, nil, nil, nil, nil, nil, nil, nil ],
                     style: [ style(sheet, left: :thin, bottom: :thin, halign: :center), value_no_top_no_left,
                             row8_c, style(sheet, bottom: :thin), row8_e, row8_f, row8_g, row8_h, i_right_line ])
      set_last_row_height(sheet, 14)
      row = sheet.rows.size
      sheet.merge_cells("A#{row}:B#{row}")
    end

    # 1明細=2行(1行目:備考、2行目:部品コード/品名/数量/単位/単価/金額)。旧ASPの列構成に合わせている。
    def build_two_row_items(sheet, items)
      header_style = style(sheet, border: :thin, bold: true, halign: :center, valign: :center, fill: "FFC0C0C0")
      sheet.add_row([ nil, "品名コード", "品名", "数量", "単位", nil, "単価", nil, "金額" ], style: Array.new(9) { header_style })
      sheet.merge_cells("G#{sheet.rows.size}:H#{sheet.rows.size}")
      set_last_row_height(sheet, 14)
      sheet.add_row([ nil, "部品コード", nil, nil, nil, nil, "定価", "海外", nil ], style: Array.new(9) { header_style })
      set_last_row_height(sheet, 14)

      items.each do |item|
        row1_default = style(sheet, top: :thin, left: :thin, right: :thin)
        row2_default = style(sheet, bottom: :thin, left: :thin, right: :thin)
        # B列(部品コード)だけ、2行の間(備考行の下辺)に破線を入れる(旧jutyu.xlsテンプレートの見た目に合わせる)
        b_row1 = style(sheet, top: :thin, left: :thin, right: :thin, bottom: :dashed)
        b_row2 = style(sheet, top: :dashed, bottom: :thin, left: :thin, right: :thin)

        # H列は本来「海外」単価用の枠だが、国内向けでも掛け率が付くことがあり、
        # その場合はこの枠に掛け率が入るため、2行のうち上段(備考行)に掛け率を表示する。
        # 0・1(掛け率なし/等倍)は通常値なので表示せず、それ以外の時だけ出す。
        rate_display = item[:rate] unless item[:rate].nil? || [ 0, 1 ].include?(item[:rate].to_f)
        sheet.add_row(
          [ nil, nil, item[:info], nil, nil, nil, nil, rate_display, nil ],
          style: [ row1_default, b_row1, row1_default, row1_default, row1_default, row1_default, row1_default,
                  style(sheet, top: :thin, left: :thin, right: :thin, halign: :right), row1_default ]
        )
        set_last_row_height(sheet, 20)
        sheet.add_row(
          [ nil, item[:code], item[:name], item[:qty], item[:unit], nil, item[:price], item[:oprice], item[:amount] ],
          style: [
            row2_default,
            b_row2,
            row2_default,
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right),
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :center),
            row2_default,
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right, number_format: "#,##0"),
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right, number_format: "#,##0"),
            style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right, number_format: "#,##0")
          ]
        )
        set_last_row_height(sheet, 20)
      end
    end

    def build_items
      @items.map do |item|
        # 部品番号あり(Orderpart)の金額は、旧ASP(asp/print211_.asp)のsmarume相当の丸めを
        # 適用した単価(定価×掛け率)に数量を掛けて求める。部品番号無(NOrderpart)は元々
        # totala(labor/宿泊費等の確定金額)を持っているのでそのまま使う。
        amount = if item.source == :orderpart
          (smarume(item.unitpd.to_f * item.rate.to_f) * item.qty.to_f).round
        else
          item.amount
        end

        {
          code: item.code,
          info: item.info,
          name: item.name,
          qty: item.qty,
          unit: item.unit,
          price: item.unitpd,
          oprice: nil,
          rate: item.rate,
          amount: amount
        }
      end
    end

    # 旧ASP(asp/include/fsysfunc.asp)のsmarume関数そのまま。四捨五入で丸めるが、
    # 桁数に応じて丸め幅が変わる(1万未満:10の位、10万未満:100の位、
    # 100万未満:1000の位、100万以上:1万の位。100万以上は値がいくら大きくなっても
    # 1万の位で頭打ち)。
    def smarume(number)
      granularity =
        if number < 10_000
          10
        elsif number < 100_000
          100
        elsif number < 1_000_000
          1_000
        else
          10_000
        end
      (number / granularity.to_f).round * granularity
    end

    # 明細行(2行1組)と同じ見た目に揃えるため、小計・累計も上段(罫線のみ)+
    # 下段(ラベル・値)の2行1組にする。
    def add_summary_row(sheet, label, value)
      top_style = style(sheet, top: :thin, left: :thin, right: :thin)
      label_style = style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right, bold: true)
      value_style = style(sheet, bottom: :thin, left: :thin, right: :thin, halign: :right, bold: true, number_format: "#,##0")
      sheet.add_row([ nil, nil, nil, nil, nil, nil, nil, nil, nil ],
                     style: [ nil, nil, nil, nil, nil, nil, nil, top_style, top_style ])
      set_last_row_height(sheet, 16)
      sheet.add_row([ nil, nil, nil, nil, nil, nil, nil, label, value ],
                     style: [ nil, nil, nil, nil, nil, nil, nil, label_style, value_style ])
      set_last_row_height(sheet, 16)
    end

    def build_footer(sheet, total_pages:, page_subtotal:, cumulative:)
      add_summary_row(sheet, "小計", page_subtotal)
      add_summary_row(sheet, "累計", cumulative) if total_pages > 1
    end
  end

  # Axlsx::Packageをラップし、serialize/to_streamの出力(=完成したxlsxのzip)に対して
  # 全シートのpageSetupへblackAndWhite="1"を挿入する。SeikyuReportのBracketShapePatchedPackage
  # と同じ手法(caxlsxが未対応の属性を、生成後のXMLへ直接書き込む)。
  class BlackAndWhitePatchedPackage < SimpleDelegator
    def initialize(package)
      super(package)
    end

    def serialize(path, *args, **kwargs)
      result = __getobj__.serialize(path, *args, **kwargs)
      patch(path)
      result
    end

    def to_stream(*args, **kwargs)
      Tempfile.create([ "xlsx_bw_patch", ".xlsx" ]) do |tmp|
        tmp.binmode
        tmp.write(__getobj__.to_stream(*args, **kwargs).read)
        tmp.flush
        patch(tmp.path)
        tmp.rewind
        StringIO.new(File.binread(tmp.path))
      end
    end

    private

    def patch(path)
      Zip::File.open(path) do |zip|
        zip.glob("xl/worksheets/sheet*.xml").each do |entry|
          xml = entry.get_input_stream.read
          next unless xml.include?("<pageSetup")

          patched = xml.sub(/<pageSetup([^\/]*)\/>/) { "<pageSetup#{Regexp.last_match(1)} blackAndWhite=\"1\"/>" }
          zip.get_output_stream(entry.name) { |f| f.write(patched) }
        end
      end
    end
  end
end
