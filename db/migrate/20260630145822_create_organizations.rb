class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :organizations, :slug, unique: true
  end
end