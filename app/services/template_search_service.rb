class TemplateSearchService
  DEFAULT_LIMIT        = 3
  SIMILARITY_THRESHOLD = 0.7
  DISTANCE_THRESHOLD   = 1 - SIMILARITY_THRESHOLD # 0.3

  def self.call(query:, user: nil, organization: nil, limit: DEFAULT_LIMIT, practice_area: nil, court_level: nil)
    new(
      query:         query,
      user:          user,
      organization:  organization,
      limit:         limit,
      practice_area: practice_area,
      court_level:   court_level
    ).call
  end

  def initialize(query:, user:, organization:, limit:, practice_area:, court_level:)
    @query        = query
    @user         = user
    @organization = organization
    @limit        = limit
    @practice_area = practice_area
    @court_level   = court_level
  end

  def call
    provider = EmbeddingProvider.active.first
    raise "No active embedding provider configured" unless provider

    adapter         = Embedding::AdapterFactory.for(provider)
    query_embedding = adapter.embed(text: @query)
 
    results = search(query_embedding)

    if results.empty?
      handle_no_results
      return { results: [], generated: true }
    end

    { results: results, generated: false }
  end

  private
  
  def search(query_embedding)
    # 1. Format the array specifically for pgvector
    formatted_embedding = "[#{query_embedding.join(',')}]"
  
    chunks_query = TemplateChunk
      .joins(:document_template)
      # 2. Use standard SQL binding placeholder '?' for safety
      .where("(embedding <=> ?) <= ?", formatted_embedding, DISTANCE_THRESHOLD)
      .merge(visible_templates)
    
    if @practice_area.present?
      chunks_query = chunks_query.where(
        document_templates: { practice_area: @practice_area }
      )
    end
  
    if @court_level.present?
      chunks_query = chunks_query
        .joins("LEFT JOIN template_court_levels ON template_court_levels.template_id = document_templates.id")
        .where("template_court_levels.court_level = ? OR template_court_levels.id IS NULL", @court_level)
    end
    
    chunks_query
      .select(
        "document_templates.id AS template_id",
        "document_templates.title",
        "document_templates.description",
        "document_templates.practice_area",
        # 3. Safely pass the formatted vector string as a bound parameter to prevent injection
        ActiveRecord::Base.sanitize_sql_array(["MIN(embedding <=> ?) AS distance", formatted_embedding])
      )
      .group(
        "document_templates.id",
        "document_templates.title",
        "document_templates.description",
        "document_templates.practice_area"
      )
      .order("distance ASC")
      .limit(@limit)
      .map do |row|
        {
          template_id:   row.template_id,
          title:         row.title,
          description:   row.description,
          practice_area: row.practice_area,
          similarity:    (1 - row.distance.to_f).round(4)
        }
      end
  end

  # Builds the visibility condition depending on whether
  # an organization context is present or not
  def visible_templates
    base = DocumentTemplate.where(status: %w[review published])

    if @organization.present?
      # Show public templates + this org's private templates
      base.where(
        "document_templates.visibility = ? OR document_templates.organization_id = ?",
        "public", @organization.id
      )
    else
      # No org context — show public templates only
      base.where(visibility: "public")
    end
  end

  def handle_no_results
    Rails.logger.info "[SearchService] No results for '#{@query}' — triggering Phase 3 generation"

    template = DocumentTemplate.create!(
      title:       @query.truncate(255),
      description: @query,
      language:    "English",
      status:      "review",
      source:      "ai_generated",
      visibility:  "public",
      # created_by and updated_by are optional — omit if no user
      created_by_id:  @user&.id,
      updated_by_id:  @user&.id
    )

    provider = LlmProvider.where(is_active: true).last
    raise "No active LLM generative provider configured" unless provider
    
    log = GenerationLog.create!(
      template:,
      trigger_type:      "search_fallback",
      prompt_summary:    @query.truncate(255),
      status:            "pending",
      llm_provider:      provider 
    )

    DocumentTemplateGenerationJob.perform_now(
      template.id.to_s,
      log.id.to_s,
      @user&.id&.to_s,  # safe navigation — passes nil if no user
      provider.id
    )
  end
end