class ChangeTaxRateDefaultOnOrders < ActiveRecord::Migration[8.1]
  def up
    change_column_null :orders, :tax_rate, true
    change_column_default :orders, :tax_rate, from: 10, to: nil
    # 個別指定なし(=全体のデフォルトに従う)を表すため、既存データの10はnilに戻す
    Order.where(tax_rate: 10).update_all(tax_rate: nil)
  end

  def down
    change_column_default :orders, :tax_rate, from: nil, to: 10
    Order.where(tax_rate: nil).update_all(tax_rate: 10)
    change_column_null :orders, :tax_rate, false
  end
end
