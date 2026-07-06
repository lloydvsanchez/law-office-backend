class CreatePhilippineLaws < ActiveRecord::Migration[8.0]
  def change
    create_table :philippine_laws, id: :uuid do |t|
      t.string  :abbreviation, null: false
      t.string  :pattern,      null: false  # regex pattern string
      t.string  :full_name,    null: false
      t.text    :description,  null: false
      t.string  :source,       null: false, default: "seeded"  # seeded | llm_discovered
      t.boolean :is_verified,  null: false, default: true
      t.integer :usage_count,  null: false, default: 0
      t.timestamps
    end

    add_index :philippine_laws, :abbreviation, unique: true
    add_index :philippine_laws, :is_verified
    add_index :philippine_laws, :source

    execute <<~SQL
      ALTER TABLE philippine_laws
      ADD CONSTRAINT chk_philippine_law_source
      CHECK (source IN ('seeded', 'llm_discovered'));
    SQL
  end
end