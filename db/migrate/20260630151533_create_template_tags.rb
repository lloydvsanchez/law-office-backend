class CreateTemplateTags < ActiveRecord::Migration[8.0]
    def change
      create_table :template_tags, id: :uuid do |t|
        t.references :template,
                     null: false,
                     type: :uuid,
                     foreign_key: { to_table: :document_templates }
  
        t.string :tag, null: false
  
        t.timestamps
      end
  
      add_index :template_tags,
                [:template_id, :tag],
                unique: true,
                name: "index_template_tags_unique"
  
      add_index :template_tags, :tag
    end
end