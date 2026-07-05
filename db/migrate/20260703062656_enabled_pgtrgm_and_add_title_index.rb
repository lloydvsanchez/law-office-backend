class EnabledPgtrgmAndAddTitleIndex < ActiveRecord::Migration[8.0]
  def up
    enable_extension "pg_trgm"

    add_index :document_templates, :title,
              using: :gin,
              opclass: :gin_trgm_ops,
              name: "index_document_templates_on_title_trgm"
  end

  def down
    remove_index :document_templates, name: "index_document_templates_on_title_trgm"
    disable_extension "pg_trgm"
  end
end