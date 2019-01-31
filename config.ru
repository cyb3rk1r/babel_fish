require 'sidekiq'

rediscloud_url = ENV.fetch('REDIS_CLOUD_URL', nil)
Sidekiq.configure_client do |config|
  defaults = { db: 1 }
  redis_params = rediscloud_url ? defaults.merge( url: rediscloud_url ) : defaults
  config.redis = redis_params
end

require 'sidekiq/web'
run Sidekiq::Web
