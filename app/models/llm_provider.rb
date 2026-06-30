class LlmProvider < ApplicationRecord
    has_many :generation_logs, dependent: :nullify
  
    store_accessor :config,
                   :api_key,
                   :temperature,
                   :max_tokens
end