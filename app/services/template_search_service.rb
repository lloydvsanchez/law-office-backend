class TemplateSearchService
  DEFAULT_LIMIT              = 3
  SIMILARITY_THRESHOLD       = 0.7
  DISTANCE_THRESHOLD         = 1 - SIMILARITY_THRESHOLD  # 0.3
  TITLE_SIMILARITY_THRESHOLD = 0.6                       # pg_trgm
  CACHE_TTL                  = 7.days  # 604,800 seconds — industry standard for stable query embeddings

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
    @query         = query
    @user          = user
    @organization  = organization
    @limit         = limit
    @practice_area = practice_area
    @court_level   = court_level
  end

  def call
    title_results    = search_by_title_and_description(limit: @limit)
    remaining_limit  = @limit - title_results.size

    semantic_results = if remaining_limit > 0
      @embedding_provider = ProviderSelector.primary(EmbeddingProvider)
      query_embedding     = embed_with_cache(@query)
      intent_results      = search_by_chunk_type(query_embedding, chunk_type: "intent",  limit: remaining_limit)
      remaining_after_intent = remaining_limit - new_results_count(intent_results, title_results)

      content_results = if remaining_after_intent > 0
        search_by_chunk_type(query_embedding, chunk_type: "content", limit: remaining_after_intent)
      else
        []
      end

      intent_results + content_results
    else
      []
    end

    combined = merge_and_deduplicate(title_results, semantic_results)
    return { results: combined, generated: false, generation_id: nil } if combined.any?

    existing = find_similar_globally
    if existing.any?
      Rails.logger.info "[SearchService] Layer 3 caught #{existing.size} similar template(s)"
      layer3_results = existing.map do |t|
        {
          template_id:   t.id,
          title:         t.title,
          description:   t.description,
          practice_area: t.practice_area,
          similarity:    nil,
          match_type:    "title"
        }
      end
      return { results: layer3_results, generated: false, generation_id: nil }
    end

    generation_id = create_and_enqueue
    { results: [], generated: true, generation_id: generation_id }

  rescue ProviderUnavailableError => e
    Rails.logger.error "[SearchService] All embedding providers unavailable: #{e.message}"
    raise
  end

  private

  # ---------------------------------------------------------------------------
  # Layer 1 — pg_trgm on title || ' ' || description
  # ---------------------------------------------------------------------------

  def search_by_title_and_description(limit:)
    query = visible_templates
      .where(
        "similarity(document_templates.title || ' ' || document_templates.description, ?) >= ?",
        @query,
        TITLE_SIMILARITY_THRESHOLD
      )

    query = query.where(document_templates: { practice_area: @practice_area }) if @practice_area.present?
    query = apply_court_level_filter(query) if @court_level.present?

    query
      .select(
        "document_templates.id AS template_id",
        "document_templates.title",
        "document_templates.description",
        "document_templates.practice_area",
        ActiveRecord::Base.sanitize_sql_array([
          "similarity(document_templates.title || ' ' || document_templates.description, ?) AS title_score",
          @query
        ])
      )
      .order(Arel.sql("title_score DESC"))
      .limit(limit)
      .map do |row|
        {
          template_id:   row.template_id,
          title:         row.title,
          description:   row.description,
          practice_area: row.practice_area,
          similarity:    row.title_score.to_f.round(4),
          match_type:    "title"
        }
      end
  end

  # ---------------------------------------------------------------------------
  # Layer 2a + 2b — vector search by chunk_type
  # ---------------------------------------------------------------------------

  def search_by_chunk_type(query_embedding, chunk_type:, limit:)
    formatted_embedding = "[#{query_embedding.join(',')}]"

    chunks_query = TemplateChunk
      .joins(:document_template)
      .where(chunk_type: chunk_type)
      .where("(embedding <=> ?) <= ?", formatted_embedding, DISTANCE_THRESHOLD)
      .merge(visible_templates)

    chunks_query = chunks_query.where(document_templates: { practice_area: @practice_area }) if @practice_area.present?
    chunks_query = apply_court_level_filter(chunks_query) if @court_level.present?

    chunks_query
      .select(
        "document_templates.id AS template_id",
        "document_templates.title",
        "document_templates.description",
        "document_templates.practice_area",
        ActiveRecord::Base.sanitize_sql_array([
          "MIN(embedding <=> ?) AS distance", formatted_embedding
        ])
      )
      .group(
        "document_templates.id",
        "document_templates.title",
        "document_templates.description",
        "document_templates.practice_area"
      )
      .order(Arel.sql("distance ASC"))
      .limit(limit)
      .map do |row|
        {
          template_id:   row.template_id,
          title:         row.title,
          description:   row.description,
          practice_area: row.practice_area,
          similarity:    (1 - row.distance.to_f).round(4),
          match_type:    chunk_type == "intent" ? "semantic_intent" : "semantic_content"
        }
      end
  end

  # ---------------------------------------------------------------------------
  # Merge — title → intent → content, deduplicate by template_id
  # ---------------------------------------------------------------------------

  def merge_and_deduplicate(*result_sets)
    seen_ids = Set.new
    merged   = []

    result_sets.each do |results|
      results.each do |r|
        merged << r if seen_ids.add?(r[:template_id])
      end
    end

    merged
  end

  # Count how many results from a new set aren't already in existing results
  def new_results_count(new_results, existing_results)
    existing_ids = existing_results.map { |r| r[:template_id] }.to_set
    new_results.count { |r| !existing_ids.include?(r[:template_id]) }
  end

  # ---------------------------------------------------------------------------
  # Layer 3 — global similarity guard before generating
  # ---------------------------------------------------------------------------

  def find_similar_globally
    DocumentTemplate
      .where(
        "similarity(title || ' ' || description, ?) >= ?",
        @query,
        TITLE_SIMILARITY_THRESHOLD
      )
      .order(Arel.sql(
        ActiveRecord::Base.sanitize_sql_array([
          "similarity(title || ' ' || description, ?) DESC", @query
        ])
      ))
      .limit(@limit)
  end

  def create_and_enqueue
    Rails.logger.info "[SearchService] No duplicates found — triggering Phase 3 generation for '#{@query}'"
  
    # Enrich the query with full Philippine law references before generation
    enriched_description = QueryEnrichmentService.call(query: @query)
    Rails.logger.info "[SearchService] Enriched query: '#{enriched_description}'" if enriched_description != @query
  
    template = DocumentTemplate.create!(
      title:          @query.truncate(255),  # temporary — overwritten by generation service
      description:    enriched_description,  # enriched query used as generation prompt
      language:       "English",
      status:         "review",
      source:         "ai_generated",
      visibility:     "public",
      created_by_id:  @user&.id,
      updated_by_id:  @user&.id
    )
  
    llm_provider = ProviderSelector.primary(LlmProvider)
  
    log = GenerationLog.create!(
      template:       template,
      trigger_type:   "search_fallback",
      prompt_summary: enriched_description.truncate(255),
      status:         "pending",
      llm_provider:   llm_provider
    )
  
    DocumentTemplateGenerationJob.perform_later(
      template.id.to_s,
      log.id.to_s,
      @user&.id&.to_s,
      llm_provider.id
    )
  
    log.id
  end

  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------

  def visible_templates
    base = DocumentTemplate.where(status: %w[review published])

    if @organization.present?
      base.where(
        "document_templates.visibility = ? OR document_templates.organization_id = ?",
        "public", @organization.id
      )
    else
      base.where(visibility: "public")
    end
  end

  def apply_court_level_filter(query)
    query
      .joins("LEFT JOIN template_court_levels ON template_court_levels.template_id = document_templates.id")
      .where("template_court_levels.court_level = ? OR template_court_levels.id IS NULL", @court_level)
  end

  # Cache query embeddings in Solid Cache — 7 day TTL
  # Key includes model name so cache auto-invalidates on provider/model change
  def embed_with_cache(text)
    model_name  = @embedding_provider.model
    cache_key   = "embedding:query:#{Digest::SHA256.hexdigest(text)}:#{model_name}"

    cached = Rails.cache.read(cache_key)
    if cached
      Rails.logger.debug "[SearchService] Embedding cache HIT for query: '#{text.truncate(50)}'"
      return cached
    end

    Rails.logger.debug "[SearchService] Embedding cache MISS — calling provider for: '#{text.truncate(50)}'"
    embedding = embed_with_fallback(text)
    Rails.cache.write(cache_key, embedding, expires_in: CACHE_TTL)
    embedding
  end

  def embed_with_fallback(text)
    adapter = Embedding::AdapterFactory.for(@embedding_provider)
    result  = adapter.embed(text: text)
    ProviderSelector.handle_success(@embedding_provider)
    result

  rescue => e
    ProviderSelector.handle_failure(@embedding_provider, error: e)
    Rails.logger.warn "[SearchService] Primary EmbeddingProvider '#{@embedding_provider.name}' failed — trying fallback"

    fallback = ProviderSelector.fallback(EmbeddingProvider, exclude: @embedding_provider)
    raise ProviderUnavailableError.new(EmbeddingProvider) unless fallback

    @embedding_provider = fallback
    adapter             = Embedding::AdapterFactory.for(@embedding_provider)
    result              = adapter.embed(text: text)
    ProviderSelector.handle_success(@embedding_provider)
    result
  end
end