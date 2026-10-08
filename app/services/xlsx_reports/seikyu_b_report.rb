# frozen_string_literal: true

module XlsxReports
  # 請求書B(seikyu.xls / asp/A4pseikyuB.asp相当)。「消費税・値引きが入らない形式」の請求書。
  # 様式・明細・ページの分け方は請求書A(SeikyuReport)と同じで、違いは最後の集計だけ。
  # - 値引・値引後合計・消費税・総合計は出さない
  # - 最終ページは、1ページだけなら「合計」の1行、複数ページなら「小計」と「合計」の2行。
  #   合計の行のC列に「消費税抜き価格」と添える
  # - 取引銀行・登録番号は請求書Aと同じく出す
  # (旧A4pseikyuB.aspでは複数ページのとき、累計の行を合計の行が上書きするため、累計は出ない)
  class SeikyuBReport < SeikyuReport
    def filename
      "seikyu_b_#{@order.mno}.xlsx"
    end

    private

    def build_footer(sheet, page_no:, total_pages:, page_subtotal:, cumulative:, is_last:)
      return super unless is_last

      add_summary_row(sheet, "小計", page_subtotal) if total_pages > 1
      add_summary_row(sheet, "合計", cumulative, note: "消費税抜き価格")
      build_bank_footer(sheet) if show_bank_footer?
    end
  end
end
