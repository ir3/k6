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

  # 新規登録(取引台帳追加)で、画面に項目が無いので既定値を入れる列。
  # 掛け率は実データで最も多い 1.0 / 0.0（船籍マスタのrateは注文の掛け率に反映されていない）、
  # tvalid は有効(1)。
  NEW_ORDER_DEFAULTS = { irate: 1.0, irate2: 0.0, tvalid: 1 }.freeze

  # 管理番号の連番(下3桁)の最大
  MNO_SEQ_MAX = 999

  # 新しい管理番号（YYYYMMNNN: 年4桁 + 月2桁 + 連番3桁）。
  # 旧ASP(orderin.asp)は「全体の最大+1、今月の先頭より小さければ今月の先頭+1」だったが、
  # 全体の最大を使うと、年月が2倍になった異常な番号(405024078)がひとつあるだけで以降の番号が壊れる。
  # そのため今月の範囲(YYYYMM001〜999)だけで最大+1にする。月が替わると 1 から始まるのは同じ。
  # 削除済みの注文も数えて、削除した番号を再発行しない。連番が999を超えたら nil。
  def self.next_mno(date = Date.current)
    base = date.year * 100_000 + date.month * 1000
    last = unscoped.where(mno: (base + 1)..(base + MNO_SEQ_MAX)).maximum(:mno)
    seq = (last || base) - base + 1
    seq <= MNO_SEQ_MAX ? base + seq : nil
  end

  # 注文の削除（旧 orderdel.asp 相当）。
  # 注文台帳は論理削除（deleted_at）、部品明細(orderparts)と部品番号なし明細(n_orderparts)は物理削除。
  # 在庫台帳(stocks)は旧ASPと同じく触らない。
  # （n_orderparts は旧ASPでは残っていたが、削除した注文に孤立行が残らないよう一緒に消す）
  def delete_with_parts!
    transaction do
      Orderpart.unscoped.where(mno: mno).delete_all
      NOrderpart.where(mno: mno).delete_all
      update!(deleted_at: Time.current)
    end
  end

  # 部品明細の並び順(sno)の刻み
  PART_SNO_STEP = 10

  # 部品明細(部品番号あり: orderparts、部品番号なし: n_orderparts)に追加する行の並び順の番号。
  # 既存の最大値+10。旧ASPの「件数×10+10」は欠番や削除で重複したので使わない
  # （実データでは12%の注文でsnoが重複していた）。
  def next_part_sno
    current = [
      Orderpart.where(mno: mno).reorder(nil).maximum(:sno),
      NOrderpart.where(mno: mno).maximum(:sno)
    ].compact.max
    current.to_i + PART_SNO_STEP
  end
end
