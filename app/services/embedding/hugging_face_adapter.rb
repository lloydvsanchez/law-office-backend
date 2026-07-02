module Embedding
  class HuggingFaceAdapter < BaseAdapter
    API_BASE = "https://api-inference.huggingface.co/pipeline/feature-extraction".freeze

    def embed(text:)
      api_key = config["api_key"]
      raise ArgumentError, "HuggingFace API key is missing" if api_key.blank?

      response = HTTParty.post(
        "#{API_BASE}/#{model}",
        headers: {
          "Authorization" => "Bearer #{api_key}",
          "Content-Type"  => "application/json"
        },
        body: { inputs: text, options: { wait_for_model: true } }.to_json
      )

      raise "HuggingFace embedding error: #{response.body}" unless response.success?

      # HuggingFace returns nested arrays for batch input; we send one string so unwrap one level
      result = response.parsed_response
      result.first.is_a?(Array) ? result.first : result
    end
  end
end