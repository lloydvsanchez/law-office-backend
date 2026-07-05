module ProviderHealthTrackable
  extend ActiveSupport::Concern

  STATUSES = %w[healthy rate_limited quota_exhausted unreachable].freeze

  included do
    scope :enabled,         -> { where(is_enabled: true) }
    scope :healthy,         -> { enabled.where(status: "healthy").order(priority: :asc) }
    scope :degraded,        -> { enabled.where.not(status: "healthy") }
    scope :recoverable,     -> { degraded.where("quota_resets_at <= ?", Time.current) }

    validates :status,            inclusion: { in: STATUSES }
    validates :priority,          presence: true, numericality: { greater_than: 0 }
    validates :failure_threshold, presence: true, numericality: { greater_than: 0 }
  end

  # Called on successful use
  def record_success!
    update!(
      failure_count:  0,
      status:         "healthy",
      last_used_at:   Time.current,
      last_error:     nil,
      quota_resets_at: nil
    )
  end

  # Called on failed use — increments failure count and marks degraded if threshold reached
  def record_failure!(error:, status: nil)
    new_failure_count = failure_count + 1
    new_status        = if new_failure_count >= failure_threshold
      status || detect_status_from_error(error)
    else
      self.status # keep current status until threshold is reached
    end

    update!(
      failure_count: new_failure_count,
      status:        new_status,
      last_error:    error.message.truncate(500)
    )
  end

  # Called by the recovery job when quota_resets_at is known and has passed
  def auto_recover!
    return unless quota_resets_at.present? && quota_resets_at <= Time.current

    update!(
      status:          "healthy",
      failure_count:   0,
      last_error:      nil,
      quota_resets_at: nil
    )
  end

  # Called by the health check job after a successful ping
  def mark_healthy!
    update!(
      status:         "healthy",
      failure_count:  0,
      last_error:     nil,
      last_checked_at: Time.current,
      quota_resets_at: nil
    )
  end

  def healthy?
    status == "healthy" && is_enabled?
  end

  private

  # Infer the degraded status from the HTTP error response
  def detect_status_from_error(error)
    message = error.message.downcase
    if message.include?("429") || message.include?("rate limit")
      "rate_limited"
    elsif message.include?("402") || message.include?("quota") || message.include?("exhausted")
      "quota_exhausted"
    else
      "unreachable"
    end
  end
end