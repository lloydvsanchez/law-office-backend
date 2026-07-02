module Embedding
  class AdapterFactory
    ADAPTERS = {
      "ollama"       => Embedding::OllamaAdapter,
      "hugging_face" => Embedding::HuggingFaceAdapter
    }.freeze

    def self.for(provider)
      adapter_class = ADAPTERS[provider.adapter_key]
      raise ArgumentError, "Unknown embedding adapter key: #{provider.adapter_key}" unless adapter_class
      adapter_class.new(provider)
    end
  end
end