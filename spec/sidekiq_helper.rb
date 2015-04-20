require 'sidekiq/testing'
require 'mock_redis'

Sidekiq::Testing.disable!

Sidekiq.configure_server do |config|
  config.redis = ConnectionPool.new(size: 1) { MockRedis.new }
end
Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::Debounce
  end

  config.redis = ConnectionPool.new(size: 1) { MockRedis.new }
end
