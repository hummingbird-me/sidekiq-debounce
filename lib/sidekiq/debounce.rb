require 'sidekiq/debounce/version'
require 'sidekiq/api'

module Sidekiq
  class Debounce
    def call(worker, msg, _queue, redis_pool = nil)
      @worker = worker.is_a?(String) ? worker.constantize : worker
      @msg = msg

      return yield unless debounce?

      block = Proc.new do |conn|
        # Get JID of the already-scheduled job, if there is one
        scheduled_jid = conn.get(debounce_key)

        # Reschedule the old job to when this new job is scheduled for
        # Or yield if there isn't one scheduled yet
        jid = scheduled_jid ? reschedule(scheduled_jid, @msg['at']) : yield

        store_expiry(conn, jid, @msg['at'])
        return false if scheduled_jid
        jid
      end

      if redis_pool
        redis_pool.with(&block)
      else
        Sidekiq.redis(&block)
      end
    end

    private

    def store_expiry(conn, job, time)
      jid = job.respond_to?(:has_key?) && job.key?('jid') ? job['jid'] : job
      conn.set(debounce_key, jid)
      conn.expireat(debounce_key, time.to_i)
    end

    def debounce_key
      hash = Digest::MD5.hexdigest(@msg['args'].to_json)
      @debounce_key ||= "sidekiq_debounce:#{@worker.name}:#{hash}"
    end

    def scheduled_set
      @scheduled_set ||= Sidekiq::ScheduledSet.new
    end

    def reschedule(jid, at)
      job = scheduled_set.find_job(jid)
      return if job.nil?

      at = if at && max_seconds
        Time.at [(job.created_at + max_seconds).to_i, at.to_i].min
      else
        at
      end

      job.reschedule(at) if job.at != at
      jid
    end

    def debounce_options_hash
      opt = @msg['at'] && @worker.get_sidekiq_options['debounce']
      opt.is_a?(Hash) ? opt : Hash.new
    end

    def debounce?
      !debounce_options_hash.nil?
    end

    def max_seconds
      debounce_options_hash && debounce_options_hash.fetch(:max_seconds) { nil }
    end
  end
end
