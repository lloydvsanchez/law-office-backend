# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
if Rails.env.development?
  EmbeddingProvider.find_or_create_by(adapter_key: "ollama") do |p|
    p.name      = "Ollama (local)"
    p.model     = ENV.fetch("OLLAMA_EMBEDDING_MODEL", "nomic-embed-text")
    p.config    = { "base_url" => ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434") }
    p.is_active = true
  end
else
  EmbeddingProvider.find_or_create_by(adapter_key: "hugging_face") do |p|
    p.name      = "HuggingFace Inference API"
    p.model     = "sentence-transformers/all-MiniLM-L6-v2"
    p.config    = { "api_key" => ENV["HUGGINGFACE_API_KEY"] }
    p.is_active = true
  end
end