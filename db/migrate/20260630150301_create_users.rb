class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :uuid do |t|
      t.references :organization,
                   type: :uuid,
                   null: false,
                   foreign_key: true

      t.string :name
      t.string :email, null: false
      t.string :role
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end