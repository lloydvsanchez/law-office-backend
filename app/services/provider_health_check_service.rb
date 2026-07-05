class ProviderHealthCheckService
  # Minimal test input — cheap, short, deterministic
  TEST_TEXT = "health check".freeze
  TEST_PROMPT = "Reply with the word OK only.".freeze

  def self.check(provider)
    new(provider).check
  end

  def initialize(provider)
    @provider = provider
  end

  def check
    case @provider
    when EmbeddingProvider then check_embedding
    when LlmProvider       then check_llm
    else raise ArgumentError, "Unknown provider type: #{@provider.class.name}"
    end
  end

  private

  def check_embedding
    adapter = Embedding::AdapterFactory.for(@provider)
    adapter.embed(text: TEST_TEXT)

    @provider.mark_healthy!
    Rails.logger.info "[HealthCheck] EmbeddingProvider '#{@provider.name}' is healthy"
    true

  rescue => e
    Rails.logger.warn "[HealthCheck] EmbeddingProvider '#{@provider.name}' failed ping: #{e.message}"
    @provider.record_failure!(error: e)
    false
  end

  def check_llm
    adapter = Llm::AdapterFactory.for(@provider)
    adapter.generate(prompt: TEST_PROMPT)

    @provider.mark_healthy!
    Rails.logger.info "[HealthCheck] LlmProvider '#{@provider.name}' is healthy"
    true

  rescue => e
    Rails.logger.warn "[HealthCheck] LlmProvider '#{@provider.name}' failed ping: #{e.message}"
    @provider.record_failure!(error: e)
    false
  end
end