class DocumentTemplateGenerationService
  def initialize(document_template:, generation_log:)
    @template = document_template
    @log      = generation_log
  end

  def call
    provider = ProviderSelector.primary(LlmProvider)
    result   = call_with_fallback(provider)

    @template.update!(
      content_raw:     result[:content],
      status:          "review",
      current_version: 1
    )

    @log.update!(
      llm_provider:      provider,
      prompt_tokens:     result[:prompt_tokens],
      completion_tokens: result[:completion_tokens],
      status:            "success"
    )
  rescue ProviderUnavailableError => e
    handle_failure(e)
    raise
  rescue => e
    handle_failure(e)
    raise
  end

  private

  def call_with_fallback(primary_provider)
    adapter = Llm::AdapterFactory.for(primary_provider)
    result  = adapter.generate(prompt: @template.description)
    ProviderSelector.handle_success(primary_provider)
    result.merge(provider: primary_provider)

  rescue => e
    ProviderSelector.handle_failure(primary_provider, error: e)
    Rails.logger.warn "[GenerationService] Primary LlmProvider failed — trying fallback"

    fallback = ProviderSelector.fallback(LlmProvider, exclude: primary_provider)
    raise ProviderUnavailableError.new(LlmProvider) unless fallback

    adapter = Llm::AdapterFactory.for(fallback)
    result  = adapter.generate(prompt: @template.description)
    ProviderSelector.handle_success(fallback)
    result.merge(provider: fallback)
  end

  def handle_failure(error)
    @log.update!(
      status:        "failed",
      error_message: error.message.truncate(500)
    )
  end
end