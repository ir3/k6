# frozen_string_literal: true

# 帳票出力履歴(旧Access「取引管理」)。帳票を出力するたびに1行追加する(追記専用)。
# kubun は出力した帳票の区分で、旧ASPの値をそのまま引き継ぐ。
class OrderLog < ActiveRecord::Base
  KUBUN_MITSUMORI_IRAI = 1 # 部品見積依頼(print211_)
  KUBUN_MITSUMORI      = 2 # 見積書(print111r / print311r)
  KUBUN_JUCHU_MEMO     = 3 # 受注メモ(jutyu111)
  KUBUN_SYUKKA_ANNAI   = 4 # 出荷案内書(A4pshuka)。請求書・納品書・受領書は、これの最古の日付を出荷日に使う
  KUBUN_SEIKYU         = 5 # 請求書A/B・同控・納品書B
  KUBUN_NOHIN_A        = 7 # 納品書A(A4pnouhin)

  scope :of_order, ->(mno) { where(mno: mno) }

  # 帳票出力を1件記録する。日付は出力した日(旧ASPと同じく時刻なし)。
  def self.record(mno:, kubun:, date: Date.current)
    create!(tvalid: 1, mno: mno, kubun: kubun, datelog: date)
  end
end
