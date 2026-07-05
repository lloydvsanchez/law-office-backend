class DocumentTemplateGenerationService
  def initialize(document_template:, generation_log:)
    @template = document_template
    @log      = generation_log
  end

  def call
    provider = ProviderSelector.primary(LlmProvider)
    result   = call_with_fallback(provider)
    parsed   = parse_structured_response(result[:content])

    @template.update!(
      title:           parsed[:title],
      content_raw:     parsed[:content],
      practice_area:   parsed[:practice_area],
      document_type:   parsed[:document_type],
      status:          "review",
      current_version: 1
    )

    @log.update!(
      llm_provider:      result[:provider],
      prompt_tokens:     result[:prompt_tokens],
      completion_tokens: result[:completion_tokens],
      status:            "success"
    )
  rescue ParseError => e
    # LLM returned malformed JSON — log and fail
    handle_failure(e)
    raise
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

  def parse_structured_response(content)
    cleaned = content.to_s.gsub(/```json|```/, "").strip
    parsed  = JSON.parse(cleaned)
  
    title         = parsed["title"].to_s.strip
    body          = parsed["content"].to_s.gsub('\n', "\n").strip  # unescape \n back to real newlines
    practice_area = parsed["practice_area"].to_s.strip
    document_type = parsed["document_type"].to_s.strip
  
    if title.blank? || body.blank?
      raise ParseError, "LLM response missing required fields 'title' or 'content': #{content.truncate(200)}"
    end
  
    # Handle clarification response — treat as a generation failure
    if title == "Clarification Needed"
      raise ParseError, "LLM could not determine document type from prompt: #{@template.description.truncate(200)}"
    end
  
    {
      title:         title,
      content:       body,
      practice_area: practice_area.presence || @template.practice_area,
      document_type: document_type.presence
    }
  rescue JSON::ParserError => e
    raise ParseError, "LLM returned invalid JSON: #{e.message} — raw: #{content.to_s.truncate(200)}"
  end

  def handle_failure(error)
    @log.update!(
      status:        "failed",
      error_message: error.message.truncate(500)
    )
  end

  # Raised when the LLM returns malformed or incomplete JSON
  class ParseError < StandardError; end
end