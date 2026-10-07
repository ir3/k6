class CreateOrderLogs < ActiveRecord::Migration[8.1]
  # 旧Accessの「取引管理」。帳票を出力するたびに1行追加する履歴テーブル。
  def change
    create_table :order_logs do |t|
      t.integer :tvalid
      t.integer :mno
      t.date    :datelog
      t.integer :kubun

      t.timestamps
    end

    add_index :order_logs, [ :mno, :kubun ]
  end
end
