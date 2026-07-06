# Thread configuration — tuned for 512MB Render.com free tier
# 2 Puma threads + 2 GoodJob threads fits within memory budget
max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 2)
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Port — declared once
port ENV.fetch("PORT", 3000)

# Environment
environment ENV.fetch("RAILS_ENV", "development")

# PID file — only when explicitly requested via environment variable
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

# Allow bin/rails restart to work
plugin :tmp_restart

# Cluster mode only in production
# Development runs in single process mode — avoids macOS ARM binding issues
# and makes debugging easier
if Rails.env.production?
  workers ENV.fetch("WEB_CONCURRENCY", 1)

  on_worker_boot do
    GoodJob.restart_on_fork
  end
end