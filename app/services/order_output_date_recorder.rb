# frozen_string_literal: true

# 注文部品詳細画面の「日付更新」（旧 partsin.asp → torihikikanri.asp「取引管理の日付登録」）。
# チェックを入れた項目それぞれに、入力した日付を、手動の記録（区分 102〜107）として帳票出力履歴（order_logs）へ1行ずつ足す。
# 旧ASPと同じく、見積依頼（101）の欄にはチェックボックスが無いので、受け付ける区分は 102〜107 だけ。
# 記録は足すだけ（消さない）。画面に出る日付は、OrderOutputDates が、記録から求める。
class OrderOutputDateRecorder
  Result = Data.define(:labels, :date, :error) do
    def success? = error.nil?
  end

  # 手動の区分 → 画面の項目名（旧ASPのチェックボックスの値）
  KUBUNS = {
    102 => "最新見積出力日", 103 => "受注/受注メモ出力日", 107 => "納品書出力日",
    104 => "出荷案内出力日", 105 => "請求書出力日", 106 => "入金(確認)日"
  }.freeze
  YEARS = 1990..2100

  def initialize(order, kubuns, input_date)
    @order = order
    @kubuns = Array(kubuns)
    @input_date = input_date
  end

  def call
    kubuns = selected_kubuns
    return failure("日付を登録する項目にチェックを入れてください。") if kubuns.empty?

    date = parse_date
    return failure("日付を入力してください(例 #{Date.current.strftime('%Y/%m/%d')})。") unless date

    OrderLog.transaction do
      kubuns.each { |kubun| OrderLog.record(mno: @order.mno, kubun: kubun, date: date) }
    end
    Result.new(labels: kubuns.map { |kubun| KUBUNS.fetch(kubun) }, date: date, error: nil)
  end

  private

  # チェックされた区分のうち、受け付けるものだけ（重複は1つに）
  def selected_kubuns
    @kubuns.map { |value| IntegerInput.parse(value, 0..999) }.compact.uniq.select { |kubun| KUBUNS.key?(kubun) }
  end

  # 日付は、日付の入力欄の「2026-11-12」と、旧ASPの「2026/11/12」（全角も）を受け付ける
  def parse_date
    text = @input_date.to_s.unicode_normalize(:nfkc).strip
    return nil unless text.match?(%r{\A\d{4}[-/]\d{1,2}[-/]\d{1,2}\z})

    year, month, day = text.split(%r{[-/]}).map(&:to_i)
    return nil unless YEARS.cover?(year) && Date.valid_date?(year, month, day)

    Date.new(year, month, day)
  end

  def failure(message) = Result.new(labels: [], date: nil, error: message)
end
