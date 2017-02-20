require 'spec_helper'
require 'sidekiq/debounce'
require 'sidekiq'

class DebouncedWorker
  include Sidekiq::Worker

  sidekiq_options debounce: true

  def perform(_a, _b); end
end

class BoundedDebouncedWorker
  include Sidekiq::Worker

  sidekiq_options debounce: {max_seconds:  140}

  def perform(_a, _b); end
end

describe Sidekiq::Debounce do
  after do
    Sidekiq.redis(&:flushdb)
  end

  let(:set) { Sidekiq::ScheduledSet.new }

  it 'queues a job normally at first' do
    DebouncedWorker.perform_in(60, 'foo', 'bar')
    set.size.must_equal 1, 'set.size must be 1'
  end

  it 'ignores repeat jobs within the debounce time and reschedules' do
    now = Time.new(2011, 11, 11)
    job_id = nil

    Timecop.freeze(now) do
      job_id = DebouncedWorker.perform_in(120, 'foo', 'bar')
    end

    Timecop.freeze(now + 60) do
      DebouncedWorker.perform_in(120, 'foo', 'bar')
    end

    scheduled_seconds_away = (set.find_job(job_id).at - now).to_i
    scheduled_seconds_away.must_equal 180, 'job must be rescheduled'
    set.size.must_equal 1, 'set.size must be 1'
  end

  it 'debounces jobs based on their arguments' do
    DebouncedWorker.perform_in(60, 'boo', 'far')
    DebouncedWorker.perform_in(60, 'foo', 'bar')
    set.size.must_equal 2, 'set.size must be 2'
  end

  it 'creates the job immediately when given an instant job' do
    DebouncedWorker.perform_async('foo', 'bar')
    set.size.must_equal 0, 'set.size must be 0'
  end

  it 'does not debounce beyond a user-specified time window' do
    now = Time.new(2011, 11, 11)
    job_id = nil

    Timecop.freeze(now) do
      job_id = BoundedDebouncedWorker.perform_in(120, 'foo', 'bar')
    end

    Timecop.freeze(now + 60) do
      BoundedDebouncedWorker.perform_in(120, 'foo', 'bar')
    end

    scheduled_seconds_away = (set.find_job(job_id).at - now).to_i
    scheduled_seconds_away.must_equal 140, 'job must not debounce beyond 140s'
  end
end
