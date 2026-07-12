module Embedding
  class GeminiAdapter < BaseAdapter
    API_BASE = "https://generativelanguage.googleapis.com/v1beta/models".freeze

    def embed(text:)
      api_key = config["api_key"]
      raise ArgumentError, "Gemini API key is missing" if api_key.blank?

      response = HTTParty.post(
        "#{API_BASE}/#{model}:embedContent?key=#{api_key}",
        headers: { "Content-Type" => "application/json" },
        body: {
          model:   "models/#{model}",
          content: { parts: [{ text: text }] },
          taskType: "RETRIEVAL_QUERY"
        }.to_json
      )

      raise "Gemini embedding error: #{response.code} — #{response.body}" unless response.success?

      result = response.parsed_response
      result.dig("embedding", "values")
    end
  end
end