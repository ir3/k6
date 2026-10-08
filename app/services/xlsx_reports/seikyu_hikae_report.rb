# frozen_string_literal: true

module XlsxReports
  # 請求書控(seikyu.xls / asp/A4pseikyu2.asp相当)。
  # 請求書(SeikyuReport)と同じ様式・計算で、旧ASPとの違いは次の3点。
  # - 1ページ目の表題が「請　求　書 (控)」、2ページ目以降の見出しが「請求書(控)」
  # - 取引銀行・登録番号の欄を出さない(旧A4pseikyu2.aspでは銀行の行がコメントアウトされ、登録番号も無い)
  class SeikyuHikaeReport < SeikyuReport
    def filename
      "seikyu_hikae_#{@order.mno}.xlsx"
    end

    def cover_title
      "請　求　書 (控)"
    end

    def continuation_title
      "請求書(控)"
    end

    def show_bank_footer?
      false
    end
  end
end
