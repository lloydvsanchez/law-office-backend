class DocumentTemplateEmbeddingJob < ApplicationJob
  queue_as :embeddings

  def perform(document_template_id)
    template = DocumentTemplate.find(document_template_id)
    return if template.content_raw.blank?

    provider = ProviderSelector.primary(EmbeddingProvider)
    chunks   = DocumentTemplateChunkingService.call(template.content_raw)
 
    ActiveRecord::Base.transaction do
      template.template_chunks.delete_all

      chunks.each do |chunk|
        embedding = embed_with_fallback(provider, chunk[:content])

        template.template_chunks.create!(
          chunk_index: chunk[:chunk_index],
          content:     chunk[:content],
          embedding:   embedding
        )
      end
    end

    Rails.logger.info "[EmbeddingJob] Embedded #{chunks.size} chunks for template #{document_template_id}"
  rescue ProviderUnavailableError => e
    Rails.logger.error "[EmbeddingJob] All embedding providers unavailable: #{e.message}"
    raise
  rescue => e
    Rails.logger.error "[EmbeddingJob] Failed for template #{document_template_id}: #{e.message}"
    raise
  end

  private

  def embed_with_fallback(primary_provider, text)
    adapter = Embedding::AdapterFactory.for(primary_provider)
    result  = adapter.embed(text: text)
    ProviderSelector.handle_success(primary_provider)
    result

  rescue => e
    ProviderSelector.handle_failure(primary_provider, error: e)
    Rails.logger.warn "[EmbeddingJob] Primary EmbeddingProvider failed — trying fallback"

    fallback = ProviderSelector.fallback(EmbeddingProvider, exclude: primary_provider)
    raise ProviderUnavailableError.new(EmbeddingProvider) unless fallback

    adapter = Embedding::AdapterFactory.for(fallback)
    result  = adapter.embed(text: text)
    ProviderSelector.handle_success(fallback)
    result
  end
end