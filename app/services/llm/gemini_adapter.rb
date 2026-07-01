module Llm
  class GeminiAdapter < BaseAdapter
    API_BASE = "https://generativelanguage.googleapis.com/v1beta/models".freeze

    def generate(prompt:)
      api_key = config["api_key"]
      raise ArgumentError, "Gemini API key is missing" if api_key.blank?

      url = "#{API_BASE}/#{model}:generateContent?key=#{api_key}"

      response = HTTParty.post(
        url,
        headers: { "Content-Type" => "application/json" },
        body: {
          system_instruction: {
            parts: [{ text: system_prompt }]
          },
          contents: [
            { role: "user", parts: [{ text: prompt }] }
          ]
        }.to_json
      )

      raise "Gemini error: #{response.body}" unless response.success?

      parsed = response.parsed_response
      {
        content:           parsed.dig("candidates", 0, "content", "parts", 0, "text").to_s.strip,
        prompt_tokens:     parsed.dig("usageMetadata", "promptTokenCount").to_i,
        completion_tokens: parsed.dig("usageMetadata", "candidatesTokenCount").to_i
      }
    end
  end
end