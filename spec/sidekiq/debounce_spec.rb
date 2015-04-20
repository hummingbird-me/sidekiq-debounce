require 'spec_helper'
require 'sidekiq/debounce'
require 'sidekiq'

class DebouncedWorker
  include Sidekiq::Worker

  sidekiq_options debounce: true

  def perform(_a, _b); end
end

describe Sidekiq::Debounce do
  before do
    stub_scheduled_set
  end

  after do
    Sidekiq.redis_pool.with(&:flushdb)
  end

  let(:set) { Sidekiq::ScheduledSet.new }
  let(:sorted_entry) { Sidekiq::SortedEntry.new(set, 0, 'jid' => '54321') }

  it 'queues a job normally at first' do
    DebouncedWorker.perform_in(60, 'foo', 'bar')
    set.size.must_equal 1, 'set.size must be 1'
  end

  it 'ignores repeat jobs within the debounce time and reschedules' do
    sorted_entry.expects(:reschedule)

    DebouncedWorker.perform_in(60, 'foo', 'bar')
    DebouncedWorker.perform_in(60, 'foo', 'bar')
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

  def stub_scheduled_set
    set.stubs(:find_job).returns(sorted_entry)
    Sidekiq::Debounce.any_instance.stubs(:scheduled_set).returns(set)
  end
end
