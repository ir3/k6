# frozen_string_literal: true

# 画面から変更できるシステム全体の設定値(key-value)を保持する。
class Ksystem < ActiveRecord::Base
  # 部品見積依頼票の営業担当(key: sales_person)。ksystems に行が無いときの最終フォールバック
  DEFAULT_SALES_PERSON = "CS国内営業チーム 山口様"

  def self.get(key, default: nil)
    find_by(key: key.to_s)&.value || default
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key.to_s)
    record.update!(value: value.to_s)
  end

  # 部品見積依頼票の「営業担当」。画面(メニュー)から変更できる。
  def self.sales_person
    get("sales_person", default: DEFAULT_SALES_PERSON)
  end
end
