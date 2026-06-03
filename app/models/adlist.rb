# frozen_string_literal: true

# == Schema Information
#
# Table name: adlists
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  ruby       :string(255)
#  gender     :integer
#  birthday   :datetime
#  kbirthday  :datetime
#  zip7       :string(255)
#  address1   :string(255)
#  address2   :string(255)
#  address3   :string(255)
#  tel        :string(255)
#  fax        :string(255)
#  mtel       :string(255)
#  url        :string(255)
#  company    :string(255)
#  section    :string(255)
#  section2   :string(255)
#  position   :string(255)
#  cozip7     :string(255)
#  coad1      :string(255)
#  coad2      :string(255)
#  coad3      :string(255)
#  cotel      :string(255)
#  comail     :string(255)
#  cofax      :string(255)
#  comobile   :string(255)
#  copok      :string(255)
#  email      :string(255)
#  memo       :text
#  courl      :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  no         :string(255)
#  kbn        :string(255)
#

class Adlist < ActiveRecord::Base
  has_many :orders
  #  attr_accessible :address1, :address2, :address3, :birthday, :coad1, :coad2, :coad3, :cofax, :comail, :comobile, :company, :copok, :cotel, :courl, :cozip7, :email, :fax, :gender, :kbirthday, :memo, :mtel, :name, :position, :ruby, :section, :section2, :tel, :url, :zip7, :deleted_at

  #  acts_as_xlsx
  #  acts_as_paranoid
  default_scope -> { where('deleted_at IS NULL').order('id DESC') }

  def self.xlsx_report
    package = Adlist.to_xlsx
    header_style = { bg_color: '00', fg_color: 'FF', alignment: { horizontal: :center }, bold: true }
    bordered = package.workbook.styles.add_style(border: Axlsx::STYLE_THIN_BORDER)
    header_xf = package.workbook.styles.add_style header_style
    package.workbook.worksheets.first.tap do |sheet|
      sheet.row_style 0, header_xf
      sheet.row_style (1..-1), bordered
    end
    package.to_stream.read
  end
end
