# frozen_string_literal: true

class Order < ActiveRecord::Base
  # 消費税率(%)の全体デフォルトが未設定(Ksystemに行が無い)の場合の最終フォールバック
  FALLBACK_TAX_RATE = 10

  belongs_to :adlists, optional: true
  #  has_many :orderparts, dependent: :destroy
  default_scope -> { where('deleted_at IS NULL').order('id DESC') }
  scope :ordered, -> { where(arel_table[:orderitem].not_eq(nil)) }
  #  attr_accessible :country, :deleted_at, :engno, :etype, :glc, :glcno, :hno, :id, :idate, :inspection, :irate, :irate2, :ldate, :mdate, :memo, :mg, :mgno, :mitday, :mno, :ncomment, :ndate, :nebiki, :adlist_id, :nplase, :odate, :ono, :orderitem, :pnum, :rdate, :seiday, :shipname, :st, :syuday, :tc, :tcno, :tcondition, :tname, :updated_at, :valid, :zp, :zpno

  # 消費税率(%)の全体デフォルト。画面から変更できるKsystem("default_tax_rate")を参照する。
  def self.default_tax_rate
    Ksystem.get("default_tax_rate", default: FALLBACK_TAX_RATE.to_s).to_i
  end

  # 個別指定(tax_rate)があればそちらを、無ければ全体デフォルトを返す
  def effective_tax_rate
    tax_rate || self.class.default_tax_rate
  end
end
