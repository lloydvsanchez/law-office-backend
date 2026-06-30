class User < ApplicationRecord
    belongs_to :organization

    has_many :created_templates,
    class_name: "DocumentTemplate",
    foreign_key: :created_by_id

    has_many :template_versions,
    foreign_key: :changed_by_id

    has_many :file_attachments,
    foreign_key: :uploaded_by_id

    has_many :generation_logs,
    foreign_key: :generated_by_id

    validates :email, presence: true

    enum :role,
        {
            admin: "admin",
            lawyer: "lawyer",
            paralegal: "paralegal"
        }
end