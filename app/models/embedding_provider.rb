class EmbeddingProvider < ApplicationRecord
  ADAPTER_KEYS = %w[ollama hugging_face].freeze

  # Associations
  has_many :generation_logs, dependent: :nullify

  # Scopes
  scope :active, -> { where(is_active: true) }

  # Validations
  validates :name,        presence: true
  validates :adapter_key, presence: true,
                          inclusion: {
                            in: ADAPTER_KEYS,
                            message: "%{value} is not a supported adapter. Must be one of: #{ADAPTER_KEYS.join(', ')}"
                          }
  validates :model,       presence: true
  validates :config,      presence: true

  # config must be a Hash, not an array or scalar
  validate :config_must_be_a_hash

  private

  def config_must_be_a_hash
    errors.add(:config, "must be a JSON object") unless config.is_a?(Hash)
  end
end