class DocumentTemplate < ApplicationRecord
  belongs_to :organization, optional: true
  belongs_to :creator,
              class_name: "User",
              foreign_key: :created_by_id,
              optional: true

  belongs_to :updater,
              class_name: "User",
              foreign_key: :updated_by_id,
              optional: true

  has_many :template_versions, dependent: :destroy, foreign_key: "template_id"
  has_many :template_variables, dependent: :destroy, foreign_key: "template_id"
  has_many :template_clauses, dependent: :destroy, foreign_key: "template_id"
  has_many :template_tags, dependent: :destroy, foreign_key: "template_id"
  has_many :template_court_levels, dependent: :destroy, foreign_key: "template_id"
  has_many :file_attachments, dependent: :destroy, foreign_key: "template_id"
  has_many :generation_logs, dependent: :destroy, foreign_key: "template_id"
  has_many :template_chunks, dependent: :destroy

  after_save :enqueue_embedding, if: :saved_change_to_content_raw?

  store_accessor :metadata,
                  :jurisdiction,
                  :difficulty,
                  :ai_notes

  enum :status,
        {
          draft: "draft",
          review: "review",
          published: "published",
          archived: "archived"
        }

  scope :published, -> { where(status: "published") }
  
  private

  def enqueue_embedding
    DocumentTemplateEmbeddingJob.perform_later(id.to_s)
  end
end