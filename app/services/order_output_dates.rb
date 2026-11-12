# frozen_string_literal: true

# 注文部品詳細画面の「各種出力日」（旧 partsin.asp の請求管理）。
# 値は、取引台帳の古い日付の列ではなく、帳票出力履歴（order_logs = 旧「取引管理」）から求める。
#
# 区分（kubun）: 自動（帳票を出力すると記録される）は 1:見積依頼 2:見積 3:受注メモ 4:出荷案内 5:請求書 6:入金 7:納品書、
#               手動（日付を手で入れた）は 101〜107（自動の区分に 100 を足した区分）。
# 旧ASPと同じ決まり（区分・更新日時の順に1行ずつ読む）:
# - 手動の日付は、同じ項目の自動の日付を上書きする（自動を先に、手動をあとに読むため）
# - 見積は、自動の最初の日付が「初回見積出力日」、自動の最後の日付が「最新見積出力日」。
#   手動の見積（102）は、最新見積出力日だけを上書きする。ただし、自動の見積が2回以上あるときは、
#   2回目以降の自動の最新の記録より、更新日時が新しいときだけ（旧ASPの mnew との比較）
# - 日付が1つも無い項目は nil（画面は「未」と出す）
class OrderOutputDates
  # date は日付、manual は手動入力のとき true
  Entry = Data.define(:date, :manual)
  Result = Data.define(:request, :first_estimate, :latest_estimate, :order_memo, :delivery, :shipping, :invoice, :payment)

  # 区分（自動の区分に直したもの）→ 項目。見積(2)だけは、初回と最新に分かれるので別に扱う
  FIELDS = { 1 => :request, 3 => :order_memo, 4 => :shipping, 5 => :invoice, 6 => :payment, 7 => :delivery }.freeze
  ESTIMATE = 2
  MANUAL_OFFSET = 100

  def initialize(mno)
    @mno = mno
  end

  def call
    entries = {}
    auto_estimates = 0
    estimate_stamp = nil # 2回目以降の自動の見積の、更新日時

    rows.each do |kubun, date, stamp|
      manual = kubun > MANUAL_OFFSET
      base = manual ? kubun - MANUAL_OFFSET : kubun

      if base == ESTIMATE
        if manual
          entries[:latest_estimate] = Entry.new(date, true) if estimate_stamp.nil? || stamp > estimate_stamp
        else
          auto_estimates += 1
          entries[:first_estimate] ||= Entry.new(date, false)
          entries[:latest_estimate] = Entry.new(date, false)
          estimate_stamp = stamp if auto_estimates > 1
        end
      elsif (field = FIELDS[base])
        entries[field] = Entry.new(date, manual)
      end
    end

    Result.new(**Result.members.index_with { |member| entries[member] })
  end

  private

  # [区分, 日付, 更新日時] を、区分・更新日時の順に
  def rows
    OrderLog.where(mno: @mno).order(:kubun, :updated_at, :id).pluck(:kubun, :datelog, :updated_at)
  end
end
