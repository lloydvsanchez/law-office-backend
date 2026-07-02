class CreateTemplateChunks < ActiveRecord::Migration[8.0]
  def change
    create_table :template_chunks, id: :uuid do |t|
      t.references :document_template, null: false, foreign_key: true, type: :uuid
      t.integer    :chunk_index,       null: false  
      t.text       :content,           null: false  
      
      # Clean, native syntax. Neighbor ensures Rails sends "vector(768)" to Postgres
      t.vector     :embedding, limit: 768  
      
      t.timestamps
    end

    add_index :template_chunks, [:document_template_id, :chunk_index], unique: true
    
    # HNSW Index works flawlessly because the column dimensions are registered instantly
    add_index :template_chunks, :embedding,
              using: :hnsw,
              opclass: :vector_cosine_ops,
              name: "index_template_chunks_on_embedding_hnsw"
  end
end