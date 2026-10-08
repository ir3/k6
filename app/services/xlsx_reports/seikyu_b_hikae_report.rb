# frozen_string_literal: true

module XlsxReports
  # 請求書B控(seikyu.xls / asp/A4pseikyuB2.asp相当)。
  # 請求書B(SeikyuBReport)と同じ様式・集計(合計に「消費税抜き価格」)で、旧ASPとの違いは
  # 請求書A控と同じ次の3点。
  # - 1ページ目の表題が「請　求　書 (控)」、2ページ目以降の見出しが「請求書(控)」
  # - 取引銀行・登録番号の欄を出さない
  class SeikyuBHikaeReport < SeikyuBReport
    def filename
      "seikyu_b_hikae_#{@order.mno}.xlsx"
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
