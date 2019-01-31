require 'sidekiq'

rediscloud_url = ENV.fetch('REDISCLOUD_URL', nil)
Sidekiq.configure_client do |config|
  defaults = { db: 1 }
  config.redis = rediscloud_url ? { url: rediscloud_url } : defaults
end

require 'sidekiq/web'
run Sidekiq::Web
