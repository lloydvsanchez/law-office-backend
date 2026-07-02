class DocumentTemplateGenerationJob < ApplicationJob
  queue_as :default

  def perform(document_template_id, generation_log_id, user_id = nil)
    template = DocumentTemplate.find(document_template_id)
    log      = GenerationLog.find(generation_log_id)

    DocumentTemplateGenerationService.new(document_template: template, generation_log: log).call

    # Only notify if triggered by a real user
    if user_id.present?
      # NotificationService.notify_success(user_id, template)
    end

  rescue => e
    if user_id.present?
      # NotificationService.notify_failure(user_id, e.message)
    end

    Rails.logger.error "[DocumentTemplateGenerationJob] Failed for template #{document_template_id}: #{e.message}"
  end
end