class ProviderRecoveryJob < ApplicationJob
  queue_as :maintenance

  def perform
    # Step 1 — auto-recover providers with a known reset time that has passed
    auto_recover_by_reset_time(LlmProvider)
    auto_recover_by_reset_time(EmbeddingProvider)

    # Step 2 — ping remaining degraded providers without a known reset time
    ping_unknown_recovery(LlmProvider)
    ping_unknown_recovery(EmbeddingProvider)
  end

  private

  def auto_recover_by_reset_time(provider_class)
    provider_class.recoverable.each do |provider|
      provider.auto_recover!
      Rails.logger.info "[RecoveryJob] Auto-recovered #{provider.class.name} '#{provider.name}'"
    end
  end

  def ping_unknown_recovery(provider_class)
    # Only ping providers that have no known reset time
    provider_class.degraded.where(quota_resets_at: nil).each do |provider|
      ProviderHealthCheckService.check(provider)
    end
  end
end