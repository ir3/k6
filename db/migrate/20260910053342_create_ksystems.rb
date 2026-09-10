class CreateKsystems < ActiveRecord::Migration[8.1]
  def change
    create_table :ksystems do |t|
      t.string :key, null: false
      t.string :value

      t.timestamps
    end
    add_index :ksystems, :key, unique: true
  end
end
