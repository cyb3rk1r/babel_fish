require 'sidekiq/web'
require 'sidekiq/cron/web'
require 'redis'

$redis = Redis.new

run Sidekiq::Web