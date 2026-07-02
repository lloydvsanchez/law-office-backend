class AddPgvectorAndEmbeddingProviders < ActiveRecord::Migration[8.0]
  def up
    enable_extension "vector"

    create_table :embedding_providers, id: :uuid do |t|
      t.string  :name,        null: false
      t.string  :adapter_key, null: false  # 'ollama', 'hugging_face'
      t.string  :model,       null: false  # e.g. 'all-minilm', 'sentence-transformers/all-MiniLM-L6-v2'
      t.jsonb   :config,      default: {}  # api_key, base_url, etc.
      t.boolean :is_active,   default: false, null: false
      t.timestamps
    end

    add_index :embedding_providers, :adapter_key
    add_index :embedding_providers, :is_active
  end

  def down
    drop_table :embedding_providers
    disable_extension "vector"
  end
end