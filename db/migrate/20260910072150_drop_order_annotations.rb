class DropOrderAnnotations < ActiveRecord::Migration[8.1]
  def up
    drop_table :order_annotations
  end

  def down
    create_table :order_annotations do |t|
      t.integer :tvalid
      t.integer :mno
      t.text :comment

      t.timestamps
    end

    add_index :order_annotations, :mno
  end
end
