require 'sidekiq'
require 'sidekiq/testing'
require 'mock_redis'

# Disable Sidekiq's testing mocks and use MockRedis instead
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
