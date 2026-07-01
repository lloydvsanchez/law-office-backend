module Llm
  class OpenaiAdapter < BaseAdapter
    API_URL = "https://api.openai.com/v1/chat/completions".freeze

    def generate(prompt:)
      api_key = config["api_key"]
      raise ArgumentError, "OpenAI API key is missing" if api_key.blank?

      response = HTTParty.post(
        API_URL,
        headers: {
          "Authorization" => "Bearer #{api_key}",
          "Content-Type"  => "application/json"
        },
        body: {
          model: model,
          messages: [
            { role: "system", content: system_prompt },
            { role: "user",   content: prompt }
          ]
        }.to_json
      )

      raise "OpenAI error: #{response.body}" unless response.success?

      parsed = response.parsed_response
      {
        content:           parsed.dig("choices", 0, "message", "content").to_s.strip,
        prompt_tokens:     parsed.dig("usage", "prompt_tokens").to_i,
        completion_tokens: parsed.dig("usage", "completion_tokens").to_i
      }
    end
  end
end