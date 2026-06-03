# frozen_string_literal: true

class Orderpart < ActiveRecord::Base
  #  attr_accessible :bqty, :deleted_at, :info, :irate, :itemno, :kzaiko, :mno, :partid, :partno, :qty, :sno, :totaLWeight, :total2, :totala, :unit, :unitpd, :unitpi, :unitpi2, :unitweight, :updated_at
  #  belongs_to :order
  default_scope -> { where('deleted_at IS NULL').order('id DESC') }
end
