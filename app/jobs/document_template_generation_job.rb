class DocumentTemplateGenerationJob < ApplicationJob
  queue_as :default

  def perform(document_template_id, generation_log_id, user_id)
    template = DocumentTemplate.find(document_template_id)
    log      = GenerationLog.find(generation_log_id)

    DocumentTemplateGenerationService.new(
      document_template: template,
      generation_log:    log
    ).call

    # Hook for your in-app notification on success
    # NotificationService.notify_success(user_id, template) — you handle this

  rescue => e
    # Hook for your in-app notification on failure
    # NotificationService.notify_failure(user_id, e.message) — you handle this

    Rails.logger.error "[DocumentTemplateGenerationJob] Failed for template #{document_template_id}: #{e.message}"
  end
end