class ProviderSelector
  # Returns the highest-priority healthy provider of the given class
  # Raises if none available
  def self.primary(provider_class)
    provider = provider_class.healthy.first
    return provider if provider

    # No healthy provider — attempt auto-recovery before giving up
    attempt_auto_recovery(provider_class)

    provider = provider_class.healthy.first
    raise ProviderUnavailableError.new(provider_class), "No healthy #{provider_class.name} available" unless provider

    provider
  end

  # Returns the next healthy provider excluding the one that just failed
  # Returns nil if no fallback exists
  def self.fallback(provider_class, exclude:)
    provider_class.healthy.where.not(id: exclude.id).first
  end

  # Marks a provider as failed and records the error
  def self.handle_failure(provider, error:)
    Rails.logger.warn "[ProviderSelector] #{provider.class.name} '#{provider.name}' failed: #{error.message}"
    provider.record_failure!(error: error)
  end

  # Marks a provider as successfully used
  def self.handle_success(provider)
    provider.record_success!
  end

  private

  def self.attempt_auto_recovery(provider_class)
    recoverable = provider_class.recoverable
    return unless recoverable.any?

    recoverable.each do |provider|
      provider.auto_recover!
      Rails.logger.info "[ProviderSelector] Auto-recovered #{provider_class.name} '#{provider.name}' after quota reset"
    end
  end
end

class ProviderUnavailableError < StandardError
  def initialize(provider_class)
    super("No healthy #{provider_class.name} is available. All providers are degraded or disabled.")
  end
end