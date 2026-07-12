class EmbeddingProvider < ApplicationRecord
  include ProviderHealthTrackable

  ADAPTER_KEYS = %w[ollama hugging_face gemini].freeze

  validates :name,        presence: true
  validates :adapter_key, presence: true,
                          inclusion: {
                            in: ADAPTER_KEYS,
                            message: "%{value} is not supported. Must be one of: #{ADAPTER_KEYS.join(', ')}"
                          }
  validates :model,  presence: true
  validates :config, presence: true

  validate :config_must_be_a_hash

  private

  def config_must_be_a_hash
    errors.add(:config, "must be a JSON object") unless config.is_a?(Hash)
  end
end