class DocumentTemplateGenerationService
  DELIMITER = "---DOCUMENT---".freeze

  def initialize(document_template:, generation_log:)
    @template = document_template
    @log      = generation_log
  end

  def call
    provider = ProviderSelector.primary(LlmProvider)
    result   = call_with_fallback(provider)
    parsed   = parse_delimited_response(result[:content])

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
    handle_parse_failure(e)
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

  def parse_delimited_response(content)
    Rails.logger.debug "[GenerationService] Raw LLM response: #{content}"

    cleaned = content.to_s.gsub(/```json|```/, "").strip

    unless cleaned.include?(DELIMITER)
      raise ParseError, "LLM response missing delimiter '#{DELIMITER}' — raw: #{content.truncate(500)}"
    end

    parts = cleaned.split(DELIMITER, 2)

    unless parts.size == 2
      raise ParseError, "LLM response could not be split on delimiter — raw: #{content.truncate(500)}"
    end

    metadata_line = parts[0].strip
    document_body = parts[1].strip

    begin
      metadata = JSON.parse(metadata_line)
    rescue JSON::ParserError => e
      raise ParseError, "LLM metadata JSON invalid: #{e.message} — raw metadata: #{metadata_line.truncate(300)}"
    end

    raise ParseError, "LLM metadata is not a JSON object" unless metadata.is_a?(Hash)

    title         = metadata["title"].to_s.strip
    practice_area = metadata["practice_area"].to_s.strip
    document_type = metadata["document_type"].to_s.strip

    raise ParseError, "LLM response missing 'title' in metadata" if title.blank?
    raise ParseError, "LLM response missing document body after delimiter" if document_body.blank?

    if title == "Clarification Needed"
      raise ParseError, "LLM could not determine document type from prompt: #{@template.description.truncate(200)}"
    end

    {
      title:         title,
      content:       document_body,
      practice_area: practice_area.presence || @template.practice_area,
      document_type: document_type.presence
    }
  end

  # On ParseError — destroy the placeholder template entirely
  # so it doesn't pollute the database or block future searches
  def handle_parse_failure(error)
    Rails.logger.error "[GenerationService] ParseError — destroying placeholder template #{@template.id}: #{error.message}"

    @log.update!(
      status:        "failed",
      error_message: error.message.truncate(500)
    )

    @template.destroy!

  rescue => e
    Rails.logger.error "[GenerationService] Failed to destroy template #{@template.id}: #{e.message}"
  end

  def handle_failure(error)
    @log.update!(
      status:        "failed",
      error_message: error.message.truncate(500)
    )
  end

  class ParseError < StandardError; end
end