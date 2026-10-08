# frozen_string_literal: true

module XlsxReports
  # 納品書B(seikyu.xls / asp/A4pnouhinB.asp相当)。「消費税・値引きが入らない形式」の納品書。
  # 請求書B(SeikyuBReport)と同じ様式・集計(合計に「消費税抜き価格」)で、旧ASPとの違いは次の2点。
  # - 1ページ目の表題が「納　品　書」、2ページ目以降の見出しが「納品書」
  # - 取引銀行・登録番号の欄を出さない
  # 出力履歴の区分は、納品書Aの7ではなく請求書系と同じ5(旧A4pnouhinB.aspのkubun)。
  class NohinBReport < SeikyuBReport
    def filename
      "nohin_b_#{@order.mno}.xlsx"
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
