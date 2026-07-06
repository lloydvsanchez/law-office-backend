Rails.application.configure do
  config.good_job.execution_mode = case Rails.env
  when "production"  then :async   # runs inside web process — no separate worker needed
  when "development" then :inline  # runs jobs immediately in dev — no background threads
  when "test"        then :inline  # runs jobs immediately in test
  else :async
  end

  # ---------------------------------------------------------------------------
  # Thread configuration — tuned for 512MB Render.com free tier
  # 2 Puma threads + 2 GoodJob threads = safe memory budget
  # ---------------------------------------------------------------------------
  config.good_job.max_threads = 2

  # ---------------------------------------------------------------------------
  # Queue configuration — all queues share the 2 threads
  # Priority: default (highest) → embeddings → maintenance (lowest)
  # Lower number = higher priority in GoodJob
  # ---------------------------------------------------------------------------
  config.good_job.queues = "default:2;embeddings:1;maintenance:1"

  # How long to wait for jobs to finish when shutting down
  config.good_job.shutdown_timeout = 25  # seconds — Render.com sends SIGTERM 30s before kill

  # Preserve job records for 7 days for debugging — auto-cleanup after
  config.good_job.cleanup_preserved_jobs_before_seconds_ago = 7.days.to_i
  config.good_job.cleanup_interval_jobs                     = 1_000

  # ---------------------------------------------------------------------------
  # Cron — replaces whenever gem
  # Runs inside the same process — no crontab access needed
  # ---------------------------------------------------------------------------
  config.good_job.cron = {
    provider_health_check: {
      cron:  "*/30 * * * *",  # every 30 minutes
      class: "ProviderHealthCheckJob",
      description: "Ping degraded LLM and embedding providers to check recovery"
    },
    provider_recovery: {
      cron:  "0 * * * *",     # every hour
      class: "ProviderRecoveryJob",
      description: "Auto-recover providers whose quota reset time has passed"
    }
  }
end