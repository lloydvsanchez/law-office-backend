class FixTemplateChunksUniqueIndex < ActiveRecord::Migration[8.0]
  def up
    remove_index :template_chunks,
                 name: "index_template_chunks_on_document_template_id_and_chunk_index"

    # Safely remove the partial intent-only index if it exists from a prior migration
    begin
      remove_index :template_chunks,
                   name: "index_template_chunks_on_template_id_and_intent_unique"
    rescue ArgumentError, ActiveRecord::StatementInvalid
      # Index didn't exist — safe to continue
    end

    add_index :template_chunks,
              [:document_template_id, :chunk_type, :chunk_index],
              unique: true,
              name:   "index_template_chunks_on_template_chunk_type_and_index"
  end

  def down
    remove_index :template_chunks,
                 name: "index_template_chunks_on_template_chunk_type_and_index"

    add_index :template_chunks,
              [:document_template_id, :chunk_index],
              unique: true

    add_index :template_chunks, [:document_template_id, :chunk_type],
              unique: true,
              where:  "chunk_type = 'intent'",
              name:   "index_template_chunks_on_template_id_and_intent_unique"
  end
end