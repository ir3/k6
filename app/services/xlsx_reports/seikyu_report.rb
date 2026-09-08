# frozen_string_literal: true

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
    end

    def filename
      "seikyu_#{@order.mno}.xlsx"
    end

    private

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
      sheet.add_row([ "No.", nil, nil, nil, nil, @order.mno, "1" ],
                     style: [ style(sheet, halign: :right), nil, nil, nil, nil, style(sheet, halign: :center), style(sheet, halign: :center) ])
      set_last_row_height(sheet, 14)
      sheet.add_row([ nil, nil, "請　求　書", nil, nil, Date.current.strftime("%Y年%-m月%-d日") ],
                     style: [ nil, nil, style(sheet, size: 16, bold: true, halign: :center), nil, nil, style(sheet, halign: :center) ])
      set_last_row_height(sheet, 20)
      sheet.add_row([ nil, nil, nil, nil, nil, "(出荷日　#{shipping_date_label})" ],
                     style: [ nil, nil, nil, nil, nil, style(sheet, halign: :center, size: 9) ])
      set_last_row_height(sheet, 13)
      sheet.add_row([ @adlist&.company ], style: [ style(sheet, size: 14, bold: true) ])
      set_last_row_height(sheet, 22)
      sheet.add_row([ @adlist&.section ])
      set_last_row_height(sheet, 10)
      sheet.add_row([])
      set_last_row_height(sheet, 6)
      sheet.add_row([ nil, nil, nil, nil, COMPANY_NAME ], style: [ nil, nil, nil, nil, style(sheet, size: 12, bold: true) ])
      set_last_row_height(sheet, 14)
      sheet.add_row([ nil, nil, nil, nil, COMPANY_ADDRESS ])
      set_last_row_height(sheet, 13)
      sheet.add_row([ nil, nil, nil, nil, COMPANY_TEL ])
      set_last_row_height(sheet, 13)
      sheet.add_row([ nil, nil, nil, nil, COMPANY_FAX ])
      set_last_row_height(sheet, 13)
      sheet.add_row([])
      set_last_row_height(sheet, 6)

      # 注番/船名/型式/ENG.No.は値が長くなりがちなので、7列分をA:B/C/D:F/Gに割り振って幅を確保する
      info_header_style = style(sheet, border: :thin, halign: :center, size: 8)
      info_value_style = style(sheet, border: :thin, halign: :center, valign: :center, bold: true, size: 11)
      sheet.add_row([ "注番", nil, "船名", "型式", nil, nil, "ENG.No." ], style: Array.new(7) { info_header_style })
      set_last_row_height(sheet, 13)
      header_row = sheet.rows.size
      sheet.add_row([ @order.ono, nil, @order.shipname, @order.etype, nil, nil, @order.engno ], style: Array.new(7) { info_value_style })
      set_last_row_height(sheet, 26)
      value_row = sheet.rows.size
      sheet.add_row([])
      set_last_row_height(sheet, 2)

      [ header_row, value_row ].each do |row_no|
        sheet.merge_cells("A#{row_no}:B#{row_no}")
        sheet.merge_cells("D#{row_no}:F#{row_no}")
      end
    end

    def build_continuation_header(sheet, page_no)
      sheet.add_row([ "請求書", nil, nil, nil, "No.", @order.mno, page_no.to_s ],
                     style: [ style(sheet, size: 12, bold: true), nil, nil, nil,
                             style(sheet, halign: :right), style(sheet, halign: :center), style(sheet, halign: :center) ])
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
          unit: orderpart.unit,
          price: orderpart.unitpd,
          amount: amount
        }
      end
    end

    def add_summary_row(sheet, label, value, double: false)
      edge = double ? :double : :thin
      label_style = style(sheet, border: :thin, top: edge, bottom: edge, halign: :right)
      value_style = style(sheet, border: :thin, top: edge, bottom: edge, halign: :right, number_format: "#,##0")
      sheet.add_row([ nil, nil, nil, nil, nil, label, value ], style: [ nil, nil, nil, nil, nil, label_style, value_style ])
      set_last_row_height(sheet, 13)
    end

    def build_footer(sheet, page_no:, total_pages:, page_subtotal:, cumulative:, is_last:)
      unless is_last
        add_summary_row(sheet, "小計", page_subtotal)
        add_summary_row(sheet, "累計", cumulative) if page_no > 1
        sheet.add_row([ "", "", "次葉に続く" ])
        set_last_row_height(sheet, 13)
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
      add_summary_row(sheet, "総合計", base + tax, double: true)

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
end
