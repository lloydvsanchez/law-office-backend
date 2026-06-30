class DocumentTemplate < ApplicationRecord
    belongs_to :organization
    belongs_to :creator,
               class_name: "User",
               foreign_key: :created_by_id
  
    belongs_to :updater,
               class_name: "User",
               foreign_key: :updated_by_id,
               optional: true
  
    has_many :template_versions, dependent: :destroy
    has_many :template_variables, dependent: :destroy
    has_many :template_clauses, dependent: :destroy
    has_many :template_tags, dependent: :destroy
    has_many :template_court_levels, dependent: :destroy
    has_many :file_attachments, dependent: :destroy
    has_many :generation_logs, dependent: :destroy
  
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
end