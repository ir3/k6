class UserProfile < ApplicationRecord
  belongs_to :user
  enum :state, { offline: 0, online: 1, manager: 2, admin: 9 }, validate: true 
  validates :firstname, length: { maximum: 20 }
  validates :lastname, length: { maximum: 20 }
  def fullname
    "#{lastname} #{firstname}"
  end

  def role_color_class
    case state
    when "admin"   then "bg-error/20"   # 赤系（管理者）
    when "manager" then "bg-warning/20" # 黄系（マネージャー）
    when "offline" then "bg-base-200"   # グレー系（利用終了）
    end
  end
end


