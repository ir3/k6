# frozen_string_literal: true

module XlsxReports
  # 御見積書(部品番号なし)(print11.xls / asp/print311r.asp相当)。
  # 様式も計算も部品番号あり(MitsumoriReport)と同じで、明細の上段に部品番号を出さないだけが違う。
  # (旧print311r.asp: PartNo = "'" として、備考とItemNoだけを上段に書いている)
  class MitsumoriNoPartReport < MitsumoriReport
    def filename
      "mitsumori_nopart_#{@order.mno}.xlsx"
    end

    def show_part_no?
      false
    end
  end
end
