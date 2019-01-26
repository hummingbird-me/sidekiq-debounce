require 'spec_helper'
require 'sidekiq/debounce'
require 'sidekiq'

class DebouncedWorker
  include Sidekiq::Worker

  sidekiq_options debounce: true

  def perform(_a, _b); end
end

describe Sidekiq::Debounce do
  after do
    Sidekiq.redis(&:flushdb)
  end

  let(:set) { Sidekiq::ScheduledSet.new }
  let(:sorted_entry) { Sidekiq::SortedEntry.new(set, 0, {jid: '54321'}.to_json) }

  it 'queues a job normally at first' do
    DebouncedWorker.perform_in(60, 'foo', 'bar')
    set.size.must_equal 1, 'set.size must be 1'
  end

  it 'ignores repeat jobs within the debounce time' do
    DebouncedWorker.perform_in(60, 'foo', 'bar').wont_be_nil
    DebouncedWorker.perform_in(60, 'foo', 'bar').must_be_nil
    set.size.must_equal 1, 'set.size must be 1'
  end

  it "creates another job if the job is manually deleted within the expiry" do
    DebouncedWorker.perform_in(60, 'foo', 'bar').wont_be_nil
    set.each{|job| job.delete if job.klass == "DebouncedWorker" }
    DebouncedWorker.perform_in(60, 'foo', 'bar').wont_be_nil
  end

  it "reschedules" do
    stub_scheduled_set
    sorted_entry.expects(:reschedule)
    DebouncedWorker.perform_in(60, 'foo', 'bar')
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
