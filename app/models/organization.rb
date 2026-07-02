class Organization < ApplicationRecord
    has_many :users, dependent: :destroy
    has_many :document_templates, dependent: :destroy

    validates :name, :slug, presence: true
    validates :slug, uniqueness: true
end