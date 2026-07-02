class TemplateChunk < ApplicationRecord
  belongs_to :document_template

  validates :content,     presence: true
  validates :chunk_index, presence: true
  validates :chunk_index, uniqueness: { scope: :document_template_id }

  # pgvector nearest-neighbor scope
  # Returns chunks ordered by cosine similarity to a given embedding vector
  scope :nearest_to, ->(embedding, limit) {
    order(Arel.sql("embedding <=> '#{embedding}'"))
      .limit(limit)
  }
end