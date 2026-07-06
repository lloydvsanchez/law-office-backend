class ImproveTemplateSearchability < ActiveRecord::Migration[8.0]
  def up
    # Add chunk_type to distinguish intent chunks from content chunks
    add_column :template_chunks, :chunk_type, :string, null: false, default: "content"
    add_index  :template_chunks, :chunk_type

    # Each template has exactly one intent chunk
    add_index :template_chunks, [:document_template_id, :chunk_type],
              unique: true,
              where:  "chunk_type = 'intent'",
              name:   "index_template_chunks_on_template_id_and_intent_unique"

    # GIN trigram index on description for pg_trgm search
    add_index :document_templates, :description,
              using:   :gin,
              opclass: :gin_trgm_ops,
              name:    "index_document_templates_on_description_trgm"

    # Expression index on concatenated title + description for combined pg_trgm search
    execute <<~SQL
      CREATE INDEX index_document_templates_on_title_description_trgm
      ON document_templates
      USING gin ((title || ' ' || description) gin_trgm_ops);
    SQL

    # Add DB constraint for chunk_type values
    execute <<~SQL
      ALTER TABLE template_chunks
      ADD CONSTRAINT chk_chunk_type
      CHECK (chunk_type IN ('content', 'intent'));
    SQL
  end

  def down
    remove_index  :template_chunks, name: "index_template_chunks_on_template_id_and_intent_unique"
    remove_index  :template_chunks, :chunk_type
    remove_column :template_chunks, :chunk_type

    remove_index :document_templates, name: "index_document_templates_on_description_trgm"
    remove_index :document_templates, name: "index_document_templates_on_title_description_trgm"

    execute "ALTER TABLE template_chunks DROP CONSTRAINT chk_chunk_type;"
  end
end