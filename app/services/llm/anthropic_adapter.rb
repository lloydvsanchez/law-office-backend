module Llm
  class AnthropicAdapter < BaseAdapter
    API_URL = "https://api.anthropic.com/v1/messages".freeze

    def generate(prompt:)
      api_key = config["api_key"]
      raise ArgumentError, "Anthropic API key is missing" if api_key.blank?

      response = HTTParty.post(
        API_URL,
        headers: {
          "x-api-key"         => api_key,
          "anthropic-version" => "2023-06-01",
          "Content-Type"      => "application/json"
        },
        body: {
          model:      model,
          max_tokens: 4096,
          system:     system_prompt,
          messages: [
            { role: "user", content: prompt }
          ]
        }.to_json
      )

      raise "Anthropic error: #{response.body}" unless response.success?

      parsed = response.parsed_response
      {
        content:           parsed.dig("content", 0, "text").to_s.strip,
        prompt_tokens:     parsed.dig("usage", "input_tokens").to_i,
        completion_tokens: parsed.dig("usage", "output_tokens").to_i
      }
    end
  end
end