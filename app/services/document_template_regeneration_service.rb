class DocumentTemplateRegenerationService
  ALLOWED_STATUSES = %w[draft review].freeze

  def self.call(document_template_id:, description: nil)
    new(document_template_id: document_template_id, description: description).call
  end

  def initialize(document_template_id:, description: nil)
    @document_template_id = document_template_id
    @new_description      = description.presence
  end

  # Returns generation_log.id for polling
  def call
    @template = find_template
    validate_status!
    resolve_description!
    validate_fields!

    log = prepare_generation_log
    enqueue_regeneration(log)

    log.id
  end

  private

  # ---------------------------------------------------------------------------
  # Finders
  # ---------------------------------------------------------------------------

  def find_template
    DocumentTemplate.find(@document_template_id)
  rescue ActiveRecord::RecordNotFound
    raise RegenerationError, "DocumentTemplate not found: #{@document_template_id}"
  end

  # ---------------------------------------------------------------------------
  # Validators
  # ---------------------------------------------------------------------------

  def validate_status!
    unless ALLOWED_STATUSES.include?(@template.status)
      raise RegenerationError, "Cannot regenerate template with status '#{@template.status}'. Allowed: #{ALLOWED_STATUSES.join(', ')}"
    end
  end

  def resolve_description!
    return unless @new_description.present?

    @template.update!(description: @new_description)
    Rails.logger.info "[RegenerationService] Updated description for template #{@template.id}"
  end

  def validate_fields!
    errors = []
    errors << "title is blank"       if @template.title.blank?
    errors << "description is blank" if @template.description.blank?

    raise RegenerationError, "Cannot regenerate: #{errors.join(', ')}" if errors.any?
  end

  # ---------------------------------------------------------------------------
  # Job preparation
  # ---------------------------------------------------------------------------

  def prepare_generation_log
    # Set status to draft while regenerating
    @template.update!(status: "draft")
    Rails.logger.info "[RegenerationService] Set template #{@template.id} to draft — queuing regeneration"

    log = GenerationLog
      .where(template: @template)
      .order(created_at: :desc)
      .first

    if log
      log.update!(
        status:        "pending",
        error_message: nil,
        trigger_type:  "regeneration"
      )
      log
    else
      llm_provider = ProviderSelector.primary(LlmProvider)
      GenerationLog.create!(
        template:       @template,
        trigger_type:   "regeneration",
        prompt_summary: @template.description.truncate(255),
        status:         "pending",
        llm_provider:   llm_provider
      )
    end
  end

  def enqueue_regeneration(log)
    llm_provider = log.llm_provider || ProviderSelector.primary(LlmProvider)
    DocumentTemplateGenerationJob.perform_later(
      @template.id.to_s,
      log.id.to_s,
      nil,         # no user_id — system triggered
      llm_provider.id.to_s
    )
    Rails.logger.info "[RegenerationService] Enqueued regeneration job for template #{@template.id} — log #{log.id}"
  end

  # ---------------------------------------------------------------------------
  # Errors
  # ---------------------------------------------------------------------------

  class RegenerationError < StandardError; end
end