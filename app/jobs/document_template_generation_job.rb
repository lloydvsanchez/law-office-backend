class DocumentTemplateGenerationJob < ApplicationJob
  queue_as :default

  def perform(document_template_id, generation_log_id, user_id = nil, llm_provider_id = nil)
    template = DocumentTemplate.find(document_template_id)
    log      = GenerationLog.find(generation_log_id)

    DocumentTemplateGenerationService.new(
      document_template: template,
      generation_log:    log
    ).call

    on_success(log, user_id)

  rescue => e
    on_failure(log, user_id, e)
    Rails.logger.error "[GenerationJob] Failed for template #{document_template_id}: #{e.message}"
  end

  private

  def on_success(log, user_id)
    # Broadcast to Action Cable subscribers
    # ActionCable.server.broadcast(
    #  "generation_#{log.id}",
    #  {
    #    status:      "completed",
    #    template:    template_payload(log.template),
    #    generation_id: log.id
    #  }
    #)

    # Create in-app notification if triggered by a real user
    if user_id.present?
      create_notification(
        user_id: user_id,
        title:   "Document Template Ready",
        body:    "Your requested template '#{log.template.title}' has been generated.",
        log:     log
      )
    end
  end

  def on_failure(log, user_id, error)
    # Broadcast failure to Action Cable subscribers
    # ActionCable.server.broadcast(
    #  "generation_#{log.id}",
    #  {
    #    status:        "failed",
    #    error_message: error.message,
    #    generation_id: log.id
    #  }
    #)

    if user_id.present?
      create_notification(
        user_id: user_id,
        title:   "Document Template Generation Failed",
        body:    "We were unable to generate '#{log.template&.title}'. Please try again.",
        log:     log
      )
    end
  end

  def create_notification(user_id:, title:, body:, log:)
    Notification.create!(
      user_id:          user_id,
      title:            title,
      body:             body,
      notifiable_type:  "GenerationLog",
      notifiable_id:    log.id
    )
  rescue => e
    Rails.logger.error "[GenerationJob] Failed to create notification: #{e.message}"
  end

  def template_payload(template)
    return nil unless template.present?
    {
      id:            template.id,
      title:         template.title,
      description:   template.description,
      practice_area: template.practice_area,
      content_raw:   template.content_raw,
      status:        template.status
    }
  end
end