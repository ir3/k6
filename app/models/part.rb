# frozen_string_literal: true

# == Schema Information
#
# Table name: parts
#
#  id         :integer          not null, primary key
#  pcode      :string(255)
#  form       :string(255)
#  jname      :string(255)
#  ename      :string(255)
#  stock      :string(255)
#  sel_unit   :string(255)
#  price      :integer
#  newprice   :integer
#  weightkg   :float
#  munit      :integer
#  itemno     :string(255)
#  cordno     :string(255)
#  comment    :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Part < ActiveRecord::Base
  #  attr_accessible :comment, :cordno, :ename, :form, :itemno, :jname, :munit, :newprice, :pcode, :price, :sel_unit, :stock, :weightkg
  default_scope -> { where('deleted_at IS NULL').order('id DESC') }
end
