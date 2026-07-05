class ProviderHealthCheckJob < ApplicationJob
  queue_as :maintenance

  def perform
    degraded_providers = (LlmProvider.degraded + EmbeddingProvider.degraded)

    if degraded_providers.empty?
      Rails.logger.info "[HealthCheckJob] All providers healthy — nothing to check"
      return
    end

    degraded_providers.each do |provider|
      ProviderHealthCheckService.check(provider)
    end

    # Notify admins if everything is still down after checks
    notify_if_all_down(LlmProvider)
    notify_if_all_down(EmbeddingProvider)
  end

  private

  def notify_if_all_down(provider_class)
    return if provider_class.healthy.exists?

    message = "All #{provider_class.name.pluralize} are degraded or unreachable. Manual intervention required."
    Rails.logger.error "[HealthCheckJob] CRITICAL: #{message}"
    notify_admins(message)
  end

  def notify_admins(message)
    User.where(role: "admin").find_each do |admin|
      Notification.create!(
        user:             admin,
        title:            "Provider Outage",
        body:             message,
        notifiable_type:  nil,
        notifiable_id:    nil
      )
    end
  end
end