class AddGeminiToEmbeddingProviderAdapterKeys < ActiveRecord::Migration[8.0]
  def up
    # Drop existing constraint only if it exists
    execute <<~SQL
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'chk_adapter_key'
          AND conrelid = 'embedding_providers'::regclass
        ) THEN
          ALTER TABLE embedding_providers DROP CONSTRAINT chk_adapter_key;
        END IF;
      END $$;
    SQL

    execute <<~SQL
      ALTER TABLE embedding_providers
      ADD CONSTRAINT chk_adapter_key
      CHECK (adapter_key IN ('ollama', 'hugging_face', 'gemini'));
    SQL
  end

  def down
    execute <<~SQL
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'chk_adapter_key'
          AND conrelid = 'embedding_providers'::regclass
        ) THEN
          ALTER TABLE embedding_providers DROP CONSTRAINT chk_adapter_key;
        END IF;
      END $$;
    SQL

    execute <<~SQL
      ALTER TABLE embedding_providers
      ADD CONSTRAINT chk_adapter_key
      CHECK (adapter_key IN ('ollama', 'hugging_face'));
    SQL
  end
end