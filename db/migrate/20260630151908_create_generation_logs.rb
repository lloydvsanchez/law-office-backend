class CreateGenerationLogs < ActiveRecord::Migration[8.0]
    def change
      create_table :generation_logs, id: :uuid do |t|
        t.references :template,
                     type: :uuid,
                     foreign_key: { to_table: :document_templates }
  
        t.references :llm_provider,
                     type: :uuid,
                     foreign_key: true
  
        t.references :generated_by,
                     type: :uuid,
                     foreign_key: { to_table: :users }
  
        t.string :trigger_type
        t.text :prompt_summary
        t.integer :prompt_tokens
        t.integer :completion_tokens
        t.string :status
        t.text :error_message
  
        t.timestamps
      end
    end
end