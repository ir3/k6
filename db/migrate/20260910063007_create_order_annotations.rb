class CreateOrderAnnotations < ActiveRecord::Migration[8.1]
  def change
    create_table :order_annotations do |t|
      t.integer :tvalid
      t.integer :mno
      t.text :comment

      t.timestamps
    end

    add_index :order_annotations, :mno
  end
end
