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
        body:             { inputs: [text] }.to_json,
        follow_redirects: true
      )
    
      raise "HuggingFace embedding error: #{response.code} — #{response.body}" unless response.success?
    
      result = response.parsed_response
    
      # Debug — log shape to confirm dimensions
      Rails.logger.debug "[HuggingFaceAdapter] Response class: #{result.class}, first class: #{result.first.class}, size: #{result.first.is_a?(Array) ? result.first.size : 'N/A'}"
    
      # all-mpnet-base-v2 returns [[768 floats]] for single input
      # Unwrap one level — take first embedding from batch
      embedding = result.first.is_a?(Array) ? result.first : result
    
      Rails.logger.debug "[HuggingFaceAdapter] Final embedding size: #{embedding.size}"
    
      embedding
    end
  end
end