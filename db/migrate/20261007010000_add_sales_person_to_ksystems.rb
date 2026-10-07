class AddSalesPersonToKsystems < ActiveRecord::Migration[8.1]
  # 部品見積依頼票の「営業担当」に出す固定値。ksystems に持って帳票から参照する。
  class MigrationKsystem < ActiveRecord::Base
    self.table_name = "ksystems"
  end

  def up
    MigrationKsystem.find_or_create_by!(key: "sales_person") do |k|
      k.value = "CS国内営業チーム 山口様"
    end
  end

  def down
    MigrationKsystem.where(key: "sales_person").delete_all
  end
end
