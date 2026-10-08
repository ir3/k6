# frozen_string_literal: true

module XlsxReports
  # 物品受領書(juryo.xls / asp/A4pjuryo.asp相当)。
  # 出荷案内書(ShukkaAnnaiReport)と同じ見出し・表(No.・品番・品名・仕様・数量・単位・摘要、金額なし)で、
  # 違いは次の3点。
  # - 表題が、1ページ目は「物　品　受　領　書」、2ページ目以降の見出しは「物品受領書」
  # - 摘要の欄は明細ごとの横線を引かず、縦線だけの1つの欄にする
  # - 全ページの摘要の欄に「受　領　印」の文字と、受領印を押す円(図形)を入れる
  # 旧A4pjuryo.aspは取引管理への出力履歴を残さない(Registryのkubunはnil)。
  class JuryoReport < ShukkaAnnaiReport
    # 受領印の円は、表の見出しの14行下(明細7件目)に「受　領　印」の文字、その下の9行半ぶんに描く。
    # 円が表からはみ出さないよう、どのページの表も最低12件分(24行)の枠を出す。
    STAMP_LABEL_ITEM_INDEX = 6
    STAMP_MIN_ITEMS = 12
    STAMP_CIRCLE_TOP_ROWS = 15 # 見出し行から円の上端まで(行数)
    STAMP_CIRCLE_ROWS = 9      # 円の高さ(行数)。行の高さは14pt
    STAMP_CIRCLE_EXTRA_EMU = 70_000 # 行数のほかに足す高さ(EMU。約5.5pt)。幅(F:G)にほぼ等しくして円にする
    REMARK_COLUMN_F = 5 # 摘要のF列(0始まり)
    REMARK_WIDTH_F_EMU = 82 * 9_525 # F列(11文字≒82px)
    REMARK_WIDTH_G_EMU = 103 * 9_525 # G列(14文字≒103px)
    STAMP_MARGIN_EMU = 5 * 9_525

    def filename
      "juryo_#{@order.mno}.xlsx"
    end

    def cover_title
      "物　品　受　領　書"
    end

    def continuation_title
      "物品受領書"
    end

    private

    def table_items(items)
      items + Array.new([ STAMP_MIN_ITEMS - items.size, 0 ].max)
    end

    # 摘要の欄は左右の縦線だけ(明細ごとの横線は引かず、表の最後の行の下にだけ線を引く)
    def remark_styles(_sheet, position, last)
      bottom = position == :bottom && last ? { bottom: :thin } : {}
      [ { left: :thin }.merge(bottom), { right: :thin }.merge(bottom) ]
    end

    def remark_text(idx)
      "受　領　印" if idx == STAMP_LABEL_ITEM_INDEX
    end

    # 受領印の円は、図形として後からxlsxへ挿入する。1ページ目は、請求書系の図形(お届け先の括弧など)と
    # 同じ描画に足す(SeikyuReport#generateが使う仕組み)。2ページ目以降は、そのシートにだけ円の描画を足す。
    def extra_shapes_drawing_xml
      super.sub("</xdr:wsDr>", "#{stamp_circle_anchor_xml(@table_header_rows.first)}\n</xdr:wsDr>")
    end

    def inject_extra_shapes(path)
      super
      @table_header_rows.drop(1).each_with_index do |header_row, idx|
        sheet_no = idx + 2
        ShapePatchedPackage.inject_drawing(path, stamp_only_drawing_xml(header_row), rel_id: "rIdStamp#{sheet_no}",
                                                                                    sheet: sheet_no, drawing: sheet_no)
      end
    end

    def stamp_only_drawing_xml(header_row)
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
        #{stamp_circle_anchor_xml(header_row)}
        </xdr:wsDr>
      XML
    end

    # 摘要欄(F:G)に収まる円。header_rowはそのシートの表の見出し行(1始まり)。上端は見出しの STAMP_CIRCLE_TOP_ROWS 行下
    def stamp_circle_anchor_xml(header_row)
      top_row = header_row + STAMP_CIRCLE_TOP_ROWS - 1
      <<~XML
        <xdr:twoCellAnchor>
        <xdr:from><xdr:col>#{REMARK_COLUMN_F}</xdr:col><xdr:colOff>#{STAMP_MARGIN_EMU}</xdr:colOff><xdr:row>#{top_row}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>
        <xdr:to><xdr:col>#{REMARK_COLUMN_F + 1}</xdr:col><xdr:colOff>#{REMARK_WIDTH_G_EMU - STAMP_MARGIN_EMU}</xdr:colOff><xdr:row>#{top_row + STAMP_CIRCLE_ROWS}</xdr:row><xdr:rowOff>#{STAMP_CIRCLE_EXTRA_EMU}</xdr:rowOff></xdr:to>
        <xdr:sp macro="" textlink="">
        <xdr:nvSpPr><xdr:cNvPr id="20" name="StampCircle"/><xdr:cNvSpPr/></xdr:nvSpPr>
        <xdr:spPr>
        <a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm>
        <a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>
        <a:noFill/>
        <a:ln w="9525"><a:solidFill><a:srgbClr val="000000"/></a:solidFill></a:ln>
        </xdr:spPr>
        <xdr:txBody><a:bodyPr/><a:lstStyle/><a:p/></xdr:txBody>
        </xdr:sp>
        <xdr:clientData/>
        </xdr:twoCellAnchor>
      XML
    end
  end
end
