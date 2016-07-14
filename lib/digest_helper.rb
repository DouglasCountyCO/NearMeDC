require 'date'
require 'pry'

module Citygram
  class DigestHelper
    def digest_day
      ENV.fetch('DIGEST_DAYS').split(",").map! {|day| day.downcase.delete(' ')}
    end

    def today_as_digest_day
      Date.today.strftime('%A').downcase
    end

    def digest_day?
      digest_day.each do |day|
        if day == today_as_digest_day
          return true
        end
      end
      return false
    end

    def send_notifications
      ::Subscription.notifiables.email.paged_each do |subscription|
        if subscription.has_events?
          ::Citygram::Workers::Notifier.perform_async(subscription.id, nil)
        end
      end
      puts "Sending Digest"
    end

    def send_notifications_if_digest_day
      send_notifications if digest_day?
    end
  end
end
