# frozen_string_literal: true

module XlsxReports
  # 納品書A(seikyu.xls / asp/A4pnouhin.asp相当)。
  # 請求書(SeikyuReport)と同じ様式・計算で、旧ASPとの違いは次の2点。
  # - 1ページ目の表題が「納　品　書」、2ページ目以降の見出しが「納品書」
  # - 取引銀行・登録番号の欄を出さない
  # (出荷日の表示、小計・累計・値引・消費税・総合計、ページの分け方は請求書と同じ)
  class NohinReport < SeikyuReport
    def filename
      "nohin_#{@order.mno}.xlsx"
    end

    def cover_title
      "納　品　書"
    end

    def continuation_title
      "納品書"
    end

    def show_bank_footer?
      false
    end
  end
end
