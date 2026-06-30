class CreateTemplateVariables < ActiveRecord::Migration[8.0]
    def change
      create_table :template_variables, id: :uuid do |t|
        t.references :template,
                     type: :uuid,
                     foreign_key: { to_table: :document_templates }
  
        t.string :variable_key
        t.string :label
        t.string :data_type
        t.boolean :is_required, default: false
        t.string :default_value
        t.string :placeholder
        t.integer :sort_order
  
        t.timestamps
      end
    end
end