# frozen_string_literal: true

class Order < ActiveRecord::Base
  belongs_to :adlists, optional: true
  #  has_many :orderparts, dependent: :destroy
  default_scope -> { where('deleted_at IS NULL').order('id DESC') }
  scope :ordered, -> { where(arel_table[:orderitem].not_eq(nil)) }
  #  attr_accessible :country, :deleted_at, :engno, :etype, :glc, :glcno, :hno, :id, :idate, :inspection, :irate, :irate2, :ldate, :mdate, :memo, :mg, :mgno, :mitday, :mno, :ncomment, :ndate, :nebiki, :adlist_id, :nplase, :odate, :ono, :orderitem, :pnum, :rdate, :seiday, :shipname, :st, :syuday, :tc, :tcno, :tcondition, :tname, :updated_at, :valid, :zp, :zpno
end
