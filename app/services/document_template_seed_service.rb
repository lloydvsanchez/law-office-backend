require "fuzzy_match"

class DocumentTemplateSeedService
  # Levenshtein similarity threshold — titles scoring above this are considered duplicates
  SIMILARITY_THRESHOLD = 0.8

  PRACTICE_AREAS = %w[
    civil
    criminal
    corporate
    labor
    family
    property
    taxation
    immigration
    administrative
    intellectual_property
  ].freeze

  def self.call(limit:, practice_area: nil, provider: nil)
    new(limit: limit, practice_area: practice_area, provider: ).call
  end

  attr_reader :provider

  def initialize(limit:, practice_area: nil, provider: nil)
    @limit         = limit
    @practice_area = practice_area
    @result        = { enqueued: 0, skipped: 0, failed: 0 }
    @provider      = provider
  end

  def call
    @provider ||= LlmProvider.find_by(is_active: true)
    raise "No active LLM provider configured" unless provider

    existing_titles = DocumentTemplate.pluck(:title)
    suggestions     = fetch_suggestions(provider: provider, existing_titles: existing_titles)
    Rails.logger.info "[SeedService] LLM returned #{suggestions.size} suggestions"
    
    suggestions.each do |suggestion|
      process_suggestion(suggestion, existing_titles)
    end

    @result
  end

  private

  def fetch_suggestions(provider:, existing_titles:)
    adapter  = Llm::AdapterFactory.for(provider)
    prompt   = build_list_prompt(existing_titles)
    response = adapter.generate(prompt: prompt)
    parse_suggestions(response[:content])
  rescue => e
    Rails.logger.error "[SeedService] Failed to fetch suggestions: #{e.message}"
    []
  end

  def process_suggestion(suggestion, existing_titles)
    title = suggestion["title"].to_s.strip

    if title.blank?
      Rails.logger.warn "[SeedService] Skipping blank title in suggestion: #{suggestion.inspect}"
      @result[:skipped] += 1
      return
    end

    if similar_exists?(title, existing_titles)
      Rails.logger.info "[SeedService] Skipping '#{title}' — similar title already exists"
      @result[:skipped] += 1
      return
    end

    enqueue_generation(suggestion)
    # Add the new title to existing_titles in memory so subsequent
    # iterations in the same run also check against it
    existing_titles << title
    @result[:enqueued] += 1

  rescue => e
    Rails.logger.error "[SeedService] Failed to enqueue '#{title}': #{e.message}"
    @result[:failed] += 1
  end

  def similar_exists?(title, existing_titles)
    return false if existing_titles.empty?

    matcher = FuzzyMatch.new(existing_titles)
    match, score = matcher.find_with_score(title)
    match.present? && score >= SIMILARITY_THRESHOLD
  end

  def enqueue_generation(suggestion)
    template = DocumentTemplate.create!(
      title:        suggestion["title"].to_s.strip,
      description:  suggestion["description"].to_s.strip,
      practice_area: suggestion["practice_area"].to_s.strip,
      language:     "English",
      status:       "draft",
      source:       "ai_generated",
      visibility:   "public"
    )

    log = GenerationLog.create!(
      template: template,
      trigger_type:      "seed",
      prompt_summary:    suggestion["description"].to_s.truncate(255),
      status:            "pending",
      llm_provider: provider
    )

    # No user_id here since this is a system-triggered seed, not a lawyer request
    DocumentTemplateGenerationJob.perform_now(
      template.id.to_s,
      log.id.to_s,
      nil,
      provider.id.to_s
    )
  end

  def build_list_prompt(existing_titles)
    area_instruction = if @practice_area.present?
      "Focus specifically on the '#{@practice_area}' practice area."
    else
      "Distribute the suggestions evenly and balanced across these Philippine legal practice areas: #{PRACTICE_AREAS.join(', ')}."
    end

    exclusion_hint = if existing_titles.any?
      "Avoid suggesting documents similar to any of these already existing titles:\n#{existing_titles.first(50).join("\n")}"
    else
      "The database is currently empty, so all suggestions are welcome."
    end

    <<~PROMPT
      You are an expert in Philippine law.

      Return a JSON array of exactly #{@limit} popular Philippine legal document templates that a law firm would commonly need.

      #{area_instruction}

      #{exclusion_hint}

      Each item in the array must have exactly these keys:
      - "title": the document name (e.g. "Contract of Lease for Residential Property")
      - "description": one sentence describing what this document is for, written as a generation prompt (e.g. "Generate a contract of lease template for residential property in the Philippines compliant with the Civil Code.")
      - "practice_area": one of #{PRACTICE_AREAS.join(', ')}

      Return ONLY the raw JSON array. No explanation, no markdown, no backticks.
    PROMPT
  end

  def parse_suggestions(content)
    cleaned = content.to_s.gsub(/```json|```/, "").strip
    parsed  = JSON.parse(cleaned)
    raise "Expected an array" unless parsed.is_a?(Array)
    parsed
  rescue JSON::ParseError, RuntimeError => e
    Rails.logger.error "[SeedService] Failed to parse LLM response: #{e.message}"
    Rails.logger.error "[SeedService] Raw content: #{content}"
    []
  end
end