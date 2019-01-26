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
        current_scheduled_job = scheduled_set.find_job(conn.get(debounce_key))
        if current_scheduled_job
          # Reschedule the old job to when this new job is scheduled for
          current_scheduled_job.reschedule(@msg['at'])
          store_expiry(conn, current_scheduled_job.jid, @msg['at'])
          false # gracefully ignore newly created scheduled job
        else
          # Or yield if there isn't one scheduled yet
          conn.del(debounce_key) # just in case the scheduled job was deleted before the expiry
          yield.tap do |job_hash|
            store_expiry(conn, job_hash["jid"], @msg['at'])
          end
        end
      end

      if redis_pool
        redis_pool.with(&block)
      else
        Sidekiq.redis(&block)
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

    def debounce?
      (@msg['at'] && @worker.get_sidekiq_options['debounce']) || false
    end
  end
end
