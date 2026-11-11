# frozen_string_literal: true

# Ｂ部品ごとの在庫の設定（非表示）。旧Accessの 在庫非表示B
class CreateStockbSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :stockb_settings do |t|
      t.string :partno, null: false
      t.integer :nonview

      t.timestamps
    end
    add_index :stockb_settings, :partno, unique: true
  end
end
