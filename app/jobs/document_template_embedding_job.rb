class DocumentTemplateEmbeddingJob < ApplicationJob
  queue_as :embeddings  # separate queue from generation to avoid blocking

  def perform(document_template_id)
    template = DocumentTemplate.find(document_template_id)

    return if template.content_raw.blank?

    provider = EmbeddingProvider.find_by(is_active: true)
    raise "No active embedding provider configured" unless provider

    adapter = Embedding::AdapterFactory.for(provider)
    chunks  = DocumentTemplateChunkingService.call(template.content_raw)

    ActiveRecord::Base.transaction do
      # Delete old chunks first — content_raw may have changed
      template.template_chunks.delete_all

      chunks.each do |chunk|
        embedding = adapter.embed(text: chunk[:content])

        template.template_chunks.create!(
          chunk_index: chunk[:chunk_index],
          content:     chunk[:content],
          embedding:   embedding
        )
      end
    end

    Rails.logger.info "[EmbeddingJob] Embedded #{chunks.size} chunks for template #{document_template_id}"

  rescue => e
    Rails.logger.error "[EmbeddingJob] Failed for template #{document_template_id}: #{e.message}"
    raise  # re-raise so Active Job can retry
  end
end