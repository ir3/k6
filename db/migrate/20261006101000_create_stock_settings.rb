# 在庫メンテナンス画面で扱う、部品ごとの在庫の設定。
# 旧Accessの 標準在庫(snum)・必要在庫(znum=予測量)・在庫部品備考(旧部品コード・補足情報)・在庫非表示 を1テーブルにまとめた。
class CreateStockSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_settings do |t|
      t.string :partno, null: false
      t.integer :snum      # 標準在庫数
      t.integer :znum      # 予測量(必要在庫)
      t.string :opartno    # 旧部品コード
      t.string :memo       # 部品に関する補足情報（仕様など）
      t.integer :nonview   # 1 のとき在庫を非表示にする

      t.timestamps
    end

    add_index :stock_settings, :partno, unique: true
  end
end
