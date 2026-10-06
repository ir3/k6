# frozen_string_literal: true

class Orderpart < ActiveRecord::Base
  #  attr_accessible :bqty, :deleted_at, :info, :irate, :itemno, :kzaiko, :mno, :partid, :partno, :qty, :sno, :totaLWeight, :total2, :totala, :unit, :unitpd, :unitpi, :unitpi2, :unitweight, :updated_at
  #  belongs_to :order
  default_scope -> { where('deleted_at IS NULL').order('id DESC') }

  # 部品台帳(なければKE部品台帳)の該当部品。注文部品詳細と同じく部品番号(pcode)で探す
  def master_part
    Part.find_by(pcode: partno) || Kepart.find_by(pcode: partno)
  end

  # 数量を変える（旧 partsreg2.asp）。合計金額(totala)は 単価×数量、合計重量は 1個あたりの重量×数量 で
  # 取り直す。1個あたりの重量は部品台帳から（ASPと同じ）。台帳に無い部品は明細に持っている値を使う。
  def change_qty!(new_qty)
    per_unit = master_part ? OrderPartAdder.unit_weight(master_part) : stored_unit_weight
    update!(qty: new_qty, totala: unitpd.to_i * new_qty, totalweight: (per_unit * new_qty).round(3))
  end

  private

  # 明細に持っている1個あたりの重量。無ければ合計重量を今の数量で割る
  def stored_unit_weight
    return unitweight.to_f if unitweight.to_f.positive?

    qty.to_i.positive? ? totalweight.to_f / qty : 0.0
  end
end
