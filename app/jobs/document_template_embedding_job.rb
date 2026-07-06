class DocumentTemplateEmbeddingJob < ApplicationJob
  queue_as :embeddings

  VALID_CHUNK_TYPES = %w[content intent].freeze

  def perform(document_template_id, chunk_type = "content")
    raise ArgumentError, "Invalid chunk_type: #{chunk_type}" unless VALID_CHUNK_TYPES.include?(chunk_type)

    template = DocumentTemplate.find(document_template_id)
    provider = ProviderSelector.primary(EmbeddingProvider)
    adapter  = Embedding::AdapterFactory.for(provider)

    case chunk_type
    when "content" then embed_content_chunks(template, adapter, provider)
    when "intent"  then embed_intent_chunk(template, adapter, provider)
    end

    Rails.logger.info "[EmbeddingJob] Embedded #{chunk_type} chunks for template #{document_template_id}"

  rescue => e
    Rails.logger.error "[EmbeddingJob] Failed for template #{document_template_id} (#{chunk_type}): #{e.message}"
    raise
  end

  private

  def embed_content_chunks(template, adapter, provider)
    return if template.content_raw.blank?

    chunks = DocumentTemplateChunkingService.call(template.content_raw, chunk_type: "content")

    ActiveRecord::Base.transaction do
      template.template_chunks.where(chunk_type: "content").delete_all

      chunks.each do |chunk|
        embedding = embed_with_fallback(adapter, provider, chunk[:content])
        template.template_chunks.create!(
          chunk_index: chunk[:chunk_index],
          content:     chunk[:content],
          embedding:   embedding,
          chunk_type:  "content"
        )
      end
    end
  end

  def embed_intent_chunk(template, adapter, provider)
    intent_text = [template.title, template.description].compact.join(" ")
    return if intent_text.blank?

    embedding = embed_with_fallback(adapter, provider, intent_text)

    ActiveRecord::Base.transaction do
      template.template_chunks.where(chunk_type: "intent").delete_all

      template.template_chunks.create!(
        chunk_index: 0,  # intent chunk is always a single chunk
        content:     intent_text,
        embedding:   embedding,
        chunk_type:  "intent"
      )
    end
  end

  def embed_with_fallback(adapter, provider, text)
    result = adapter.embed(text: text)
    ProviderSelector.handle_success(provider)
    result

  rescue => e
    ProviderSelector.handle_failure(provider, error: e)
    Rails.logger.warn "[EmbeddingJob] Primary provider failed — trying fallback"

    fallback = ProviderSelector.fallback(EmbeddingProvider, exclude: provider)
    raise ProviderUnavailableError.new(EmbeddingProvider) unless fallback

    fallback_adapter = Embedding::AdapterFactory.for(fallback)
    result           = fallback_adapter.embed(text: text)
    ProviderSelector.handle_success(fallback)
    result
  end
end