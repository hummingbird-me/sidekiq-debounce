require 'simplecov'
SimpleCov.start

require 'minitest/spec'
require 'minitest/autorun'
require 'mocha/mini_test'
require 'sidekiq_helper'
require 'timecop'

Timecop.safe_mode = true
