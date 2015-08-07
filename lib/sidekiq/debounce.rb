require 'sidekiq/debounce/version'
require 'sidekiq/api'

module Sidekiq
  class Debounce
    def call(worker, msg, _queue, redis_pool)
      @worker = worker.is_a?(String) ? worker.constantize : worker
      @msg = msg

      return yield unless debounce?

      redis_pool.with do |conn|
        # Get JID of the already-scheduled job, if there is one
        scheduled_jid = conn.get(debounce_key)

        # Reschedule the old job to when this new job is scheduled for
        # Or yield if there isn't one scheduled yet
        jid = scheduled_jid ? reschedule(scheduled_jid, @msg['at']) : yield

        store_expiry(conn, jid, @msg['at'])
        return false if scheduled_jid
        jid
      end
    end

    private

    def store_expiry(conn, jid, time)
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
      job.reschedule(at) unless job.nil?
      jid
    end

    def debounce?
      (@msg['at'] && @worker.get_sidekiq_options['debounce']) || false
    end
  end
end
