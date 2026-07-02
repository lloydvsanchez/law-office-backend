module Embedding
  class OllamaAdapter < BaseAdapter
    def embed(text:)
      base_url = config["base_url"].presence || "http://localhost:11434"

      response = HTTParty.post(
        "#{base_url}/api/embed",  # current endpoint — replaces legacy /api/embeddings
        headers: { "Content-Type" => "application/json" },
        body: {
          model: model,
          input: text  # current key — replaces legacy 'prompt'
        }.to_json
      )

      raise "Ollama embedding error: #{response.body}" unless response.success?

      # /api/embed returns { "embeddings": [[...]] } — a nested array even for single input
      response.parsed_response.dig("embeddings", 0)
    end
  end
end