class CreateFileAttachments < ActiveRecord::Migration[8.0]
    def change
      create_table :file_attachments, id: :uuid do |t|
        t.references :template,
                     type: :uuid,
                     foreign_key: { to_table: :document_templates }
  
        t.references :uploaded_by,
                     type: :uuid,
                     foreign_key: { to_table: :users }
  
        t.string :original_filename
        t.string :file_type
        t.string :storage_url
        t.string :ocr_status
        t.text :extracted_text
        t.bigint :file_size_bytes
  
        t.timestamps
      end
    end
end