class CreateNOrderparts < ActiveRecord::Migration[8.1]
  def change
    create_table :n_orderparts do |t|
      t.integer :tvalid
      t.integer :mno
      t.integer :sno
      t.string :partsname
      t.string :mark
      t.string :itemno
      t.string :info
      t.float :qty
      t.integer :unitpd
      t.float :rate
      t.integer :totala
      t.float :weight
      t.string :etc

      t.timestamps
    end

    add_index :n_orderparts, :mno
  end
end
