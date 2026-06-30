class CreateTemplateVersions < ActiveRecord::Migration[8.0]
    def change
      create_table :template_versions, id: :uuid do |t|
        t.references :template,
                     type: :uuid,
                     foreign_key: { to_table: :document_templates }
  
        t.references :changed_by,
                     type: :uuid,
                     foreign_key: { to_table: :users }
  
        t.integer :version_number
        t.text :content_raw
        t.string :change_summary
  
        t.timestamps
      end
    end
end