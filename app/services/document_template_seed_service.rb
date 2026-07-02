class DocumentTemplateSeedService
  DUPLICATE_SIMILARITY_THRESHOLD = 0.75
  # Cosine distance threshold — inverse of similarity
  # 1 - 0.75 = 0.25 means vectors must be within 0.25 distance to be considered duplicates
  DUPLICATE_DISTANCE_THRESHOLD = 1 - DUPLICATE_SIMILARITY_THRESHOLD

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

  def self.call(limit:, practice_area: nil)
    new(limit: limit, practice_area: practice_area).call
  end

  def initialize(limit:, practice_area: nil)
    @limit          = limit
    @practice_area  = practice_area
    @result         = { enqueued: 0, skipped: 0, failed: 0 }
    @enqueued_titles = Set.new  # Option A — tracks same-run enqueued titles
  end

  def call
    @provider           = ProviderSelector.primary(LlmProvider)
    @embedding_provider = ProviderSelector.primary(EmbeddingProvider)

    suggestions = fetch_suggestions

    Rails.logger.info "[SeedService] LLM returned #{suggestions.size} suggestions"

    suggestions.each do |suggestion|
      process_suggestion(suggestion)
    end

    @result
  end

  private

  def fetch_suggestions
    prompt = build_list_prompt
    result = call_with_fallback(prompt)
    parse_suggestions(result[:content])
  rescue ProviderUnavailableError => e
    Rails.logger.error "[SeedService] All LLM providers unavailable: #{e.message}"
    []
  rescue => e
    Rails.logger.error "[SeedService] Failed to fetch suggestions: #{e.message}"
    []
  end

  def call_with_fallback(prompt)
    adapter = Llm::AdapterFactory.for(@provider)
    result  = adapter.generate(prompt: prompt)
    ProviderSelector.handle_success(@provider)
    result

  rescue => e
    ProviderSelector.handle_failure(@provider, error: e)
    Rails.logger.warn "[SeedService] Primary LlmProvider '#{@provider.name}' failed — trying fallback"

    fallback = ProviderSelector.fallback(LlmProvider, exclude: @provider)
    raise ProviderUnavailableError.new(LlmProvider) unless fallback

    @provider = fallback
    adapter   = Llm::AdapterFactory.for(@provider)
    result    = adapter.generate(prompt: prompt)
    ProviderSelector.handle_success(@provider)
    result
  end

  def process_suggestion(suggestion)
    title = suggestion["title"].to_s.strip

    if title.blank?
      Rails.logger.warn "[SeedService] Skipping blank title: #{suggestion.inspect}"
      @result[:skipped] += 1
      return
    end

    # Option A — fast in-memory check for same-run duplicates first
    if same_run_duplicate?(title)
      Rails.logger.info "[SeedService] Skipping '#{title}' — duplicate within this run"
      @result[:skipped] += 1
      return
    end

    # Cross-run check — semantic similarity against pgvector
    if similar_in_database?(title)
      Rails.logger.info "[SeedService] Skipping '#{title}' — similar template exists in database"
      @result[:skipped] += 1
      return
    end

    enqueue_generation(suggestion)
    @enqueued_titles << title.downcase  # register for same-run duplicate detection
    @result[:enqueued] += 1

  rescue => e
    Rails.logger.error "[SeedService] Failed to enqueue '#{title}': #{e.message}"
    @result[:failed] += 1
  end

  # Option A — case-insensitive exact match against same-run enqueued titles
  def same_run_duplicate?(title)
    @enqueued_titles.include?(title.downcase)
  end

  # Embeds the suggestion title and checks pgvector for semantically similar templates
  def similar_in_database?(title)
    return false unless TemplateChunk.exists?  # skip if pgvector is empty

    adapter   = Embedding::AdapterFactory.for(@embedding_provider)
    embedding = adapter.embed(text: title)

    TemplateChunk
      .joins(:document_template)
      .where("document_templates.status != ?", "draft")
      .where("embedding <=> ? <= ?", embedding.to_s, DUPLICATE_DISTANCE_THRESHOLD)
      .exists?

  rescue => e
    # If embedding check fails, log and allow the suggestion through
    # Better to risk a duplicate than block valid new templates
    Rails.logger.warn "[SeedService] Similarity check failed for '#{title}': #{e.message} — allowing through"
    false
  end

  def enqueue_generation(suggestion)
    template = DocumentTemplate.create!(
      title:         suggestion["title"].to_s.strip,
      description:   suggestion["description"].to_s.strip,
      practice_area: suggestion["practice_area"].to_s.strip,
      language:      "English",
      status:        "draft",
      source:        "ai_generated",
      visibility:    "public"
    )

    log = GenerationLog.create!(
      template:       template,
      trigger_type:   "seed",
      prompt_summary: suggestion["description"].to_s.truncate(255),
      status:         "pending",
      llm_provider:   @provider
    )

    DocumentTemplateGenerationJob.perform_now(
      template.id.to_s,
      log.id.to_s,
    )
  end

  def build_list_prompt
    area_instruction = if @practice_area.present?
      "Focus specifically on the '#{@practice_area}' practice area."
    else
      "Distribute the suggestions evenly and balanced across these Philippine legal practice areas: #{PRACTICE_AREAS.join(', ')}."
    end

    <<~PROMPT
      You are an expert in Philippine law.

      Return a JSON array of exactly #{@limit} popular Philippine legal document templates that a law firm would commonly need.

      #{area_instruction}

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