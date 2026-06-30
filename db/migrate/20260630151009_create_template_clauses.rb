class CreateTemplateClauses < ActiveRecord::Migration[8.0]
    def change
      create_table :template_clauses, id: :uuid do |t|
        t.references :template,
                     type: :uuid,
                     foreign_key: { to_table: :document_templates }
  
        t.string :clause_key
        t.string :label
        t.text :content
        t.string :clause_type
        t.boolean :is_optional, default: false
        t.integer :sort_order
  
        t.timestamps
      end
    end
end