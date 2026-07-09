module Embedding
  class HuggingFaceAdapter < BaseAdapter
    API_BASE = "https://router.huggingface.co/hf-inference/models".freeze

    def embed(text:)
      api_key = config["api_key"]
      raise ArgumentError, "HuggingFace API key is missing" if api_key.blank?

      response = HTTParty.post(
        "#{API_BASE}/#{model}/pipeline/feature-extraction",
        headers: {
          "Authorization" => "Bearer #{api_key}",
          "Content-Type"  => "application/json"
        },
        body: { inputs: [text] }.to_json,
        follow_redirects: true
      )

      raise "HuggingFace embedding error: #{response.code} — #{response.body}" unless response.success?

      result = response.parsed_response

      # Returns [[...]] — array of embeddings, one per input
      # We send one string so take the first
      result.first.is_a?(Array) ? result.first : result
    end
  end
end