class QueryEnrichmentService
  def self.call(query:, provider: nil)
    new(query: query, provider: provider).call
  end

  def initialize(query:, provider: nil)
    @query    = query.to_s.strip
    @provider = provider
  end

  def call
    # Step 1 — scan against active DB laws
    enriched = enrich_from_database
    return enriched if enriched != @query

    # Step 2 — LLM fallback for unrecognized references
    enrich_from_llm
  end

  private

  # ---------------------------------------------------------------------------
  # Step 1 — Database lookup
  # ---------------------------------------------------------------------------

  def enrich_from_database
    PhilippineLaw.active.find_each do |law|
      next unless law.matches?(@query)

      law.increment_usage!
      enriched = expand_query(@query, law.to_regexp, law.full_name, law.description)
      Rails.logger.info "[QueryEnrichment] Matched '#{law.abbreviation}' via database"
      return enriched
    end

    @query
  end

  # ---------------------------------------------------------------------------
  # Step 2 — LLM fallback
  # ---------------------------------------------------------------------------

  def enrich_from_llm
    provider = resolve_provider
    return @query unless provider

    adapter  = Llm::AdapterFactory.for(provider)
    response = adapter.generate(prompt: build_law_detection_prompt)
    parsed   = parse_llm_law_response(response[:content])

    return @query if parsed.nil?

    persist_discovered_law(parsed)
    expand_query(@query, Regexp.new(Regexp.escape(parsed[:abbreviation]), Regexp::IGNORECASE), parsed[:full_name], parsed[:description])

  rescue => e
    Rails.logger.warn "[QueryEnrichment] LLM law expansion failed: #{e.message} — returning original query"
    @query
  end

  def resolve_provider
    @provider || ProviderSelector.primary(LlmProvider)
  rescue ProviderUnavailableError
    Rails.logger.warn "[QueryEnrichment] No LLM provider available for law expansion — returning original query"
    nil
  end

  def build_law_detection_prompt
    known_abbreviations = PhilippineLaw.active.pluck(:abbreviation).join(", ")

    <<~PROMPT
      You are an expert in Philippine law.

      The following is a user query for a legal document:
      "#{@query}"

      Check if the query contains a Philippine law abbreviation or reference that is NOT in this list of already-known abbreviations:
      #{known_abbreviations}

      If you find an unknown Philippine law reference, respond in EXACTLY this format — three lines, nothing else:
      ABBREVIATION: [the short form exactly as it appears in the query, e.g. RA 11765]
      FULL_NAME: [the complete official name of the law]
      DESCRIPTION: [one sentence describing what the law is and what it covers]

      If there is no unknown law reference in the query, respond with exactly: NONE
      Do not add any explanation, greeting, or extra text.
    PROMPT
  end

  def parse_llm_law_response(content)
    cleaned = content.to_s.strip
    return nil if cleaned.upcase == "NONE" || cleaned.blank?

    lines        = cleaned.lines.map(&:strip).reject(&:blank?)
    abbreviation = lines.find { |l| l.start_with?("ABBREVIATION:") }&.sub("ABBREVIATION:", "")&.strip
    full_name    = lines.find { |l| l.start_with?("FULL_NAME:") }&.sub("FULL_NAME:", "")&.strip
    description  = lines.find { |l| l.start_with?("DESCRIPTION:") }&.sub("DESCRIPTION:", "")&.strip

    return nil if abbreviation.blank? || full_name.blank? || description.blank?

    Rails.logger.info "[QueryEnrichment] LLM discovered new law: #{abbreviation} → #{full_name}"
    { abbreviation: abbreviation, full_name: full_name, description: description }
  end

  def persist_discovered_law(parsed)
    # Build a pattern from the abbreviation — escape and add word boundaries
    pattern = "\\b#{Regexp.escape(parsed[:abbreviation]).gsub('\\ ', '\\s*')}\\b"

    PhilippineLaw.find_or_create_by!(abbreviation: parsed[:abbreviation]) do |law|
      law.pattern      = pattern
      law.full_name    = parsed[:full_name]
      law.description  = parsed[:description]
      law.source       = "llm_discovered"
      law.is_verified  = true
      law.usage_count  = 1
    end

    Rails.logger.info "[QueryEnrichment] Persisted new law: #{parsed[:abbreviation]}"
  rescue ActiveRecord::RecordInvalid => e
    # Race condition — another request already inserted this law
    Rails.logger.warn "[QueryEnrichment] Law already exists (race condition): #{e.message}"
  end

  # ---------------------------------------------------------------------------
  # Shared helper
  # ---------------------------------------------------------------------------

  def expand_query(query, regexp, full_name, description)
    expanded = query.gsub(regexp, full_name)
    "#{expanded} (#{description})"
  end
end