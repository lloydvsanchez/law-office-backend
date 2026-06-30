class CreateTemplateCourtLevels < ActiveRecord::Migration[8.0]
    def change
      create_table :template_court_levels, id: :uuid do |t|
        t.references :template,
                     null: false,
                     type: :uuid,
                     foreign_key: { to_table: :document_templates }
  
        t.string :court_level, null: false
  
        t.timestamps
      end
  
      add_index :template_court_levels,
                [:template_id, :court_level],
                unique: true,
                name: "index_template_court_levels_unique"
    end
end