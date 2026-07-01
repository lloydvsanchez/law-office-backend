class DocumentTemplateGenerationService
  def initialize(document_template:, generation_log:)
    @template = document_template
    @log      = generation_log
  end

  def call
    provider = LlmProvider.find_by(is_active: true)
    raise "No active LLM provider configured" unless provider

    adapter = Llm::AdapterFactory.for(provider)
    result  = adapter.generate(prompt: @template.description)

    @template.update!(
      content_raw:     result[:content],
      status:          "active",
      current_version: 1
    )

    @log.update!(
      llm_provider:      provider,
      prompt_tokens:     result[:prompt_tokens],
      completion_tokens: result[:completion_tokens],
      status:            "completed"
    )

  rescue => e
    @log.update!(
      status:        "failed",
      error_message: e.message
    )

    # Re-raise so the job layer knows generation failed
    # and can trigger the in-app notification accordingly
    raise
  end
end