class CreateDocumentTemplates < ActiveRecord::Migration[8.0]
    def change
        create_table :document_templates, id: :uuid do |t|
        t.references :organization,
                        type: :uuid,
                        null: false,
                        foreign_key: true

        t.references :created_by,
                        type: :uuid,
                        foreign_key: { to_table: :users }

        t.references :updated_by,
                        type: :uuid,
                        foreign_key: { to_table: :users }

        t.string :title, null: false
        t.string :description
        t.string :practice_area
        t.string :document_type
        t.string :language
        t.string :visibility
        t.string :status
        t.string :source

        t.integer :current_version, default: 1

        t.text :content_raw

        t.jsonb :metadata, default: {}

        t.timestamps
        end

        add_index :document_templates, :practice_area
        add_index :document_templates, :document_type
        add_index :document_templates, :status
    end
end