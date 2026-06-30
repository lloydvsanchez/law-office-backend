class CreateLlmProviders < ActiveRecord::Migration[8.0]
    def change
      create_table :llm_providers, id: :uuid do |t|
        t.string :name
        t.string :adapter_key
        t.string :model
        t.jsonb :config, default: {}
        t.boolean :is_active, default: true
  
        t.timestamps
      end
    end
end