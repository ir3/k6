class CreateUserProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :firstname
      t.string :lastname
      t.integer :state
      t.datetime :sign_in_at
      t.datetime :sign_out_at
      t.timestamps
    end
  end
end
