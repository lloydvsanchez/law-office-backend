module Llm
  class AdapterFactory
    ADAPTERS = {
      "openai"     => Llm::OpenaiAdapter,
      "anthropic"  => Llm::AnthropicAdapter,
      "gemini"     => Llm::GeminiAdapter,
      "groq"       => Llm::GroqAdapter
    }.freeze

    def self.for(provider)
      adapter_class = ADAPTERS[provider.adapter_key]
      raise ArgumentError, "Unknown adapter key: #{provider.adapter_key}" unless adapter_class
      adapter_class.new(provider)
    end
  end
end