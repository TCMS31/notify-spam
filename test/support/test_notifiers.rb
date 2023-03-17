# frozen_string_literal: true

# Stand-in notification channels for the suite. They also double as a worked
# example of the NotifierRegistry seam: a channel is one class plus one
# `register` call.
module TestNotifiers
  # Accepts everything and remembers what it was handed.
  class Recording
    include Notifier

    class << self
      attr_reader :deliveries

      def reset!
        @deliveries = []
      end
    end
    reset!

    def deliver(spam_report)
      self.class.deliveries << spam_report.id
      "recording:#{spam_report.id}"
    end
  end

  # Rejects every delivery, the way a revoked Slack token would.
  class Failing
    include Notifier

    class << self
      attr_reader :attempts

      def reset!
        @attempts = []
      end
    end
    reset!

    def deliver(spam_report)
      self.class.attempts << spam_report.id
      raise Notifier::DeliveryError, "slack delivery failed: simulated outage"
    end
  end

  # Fails for one specific report and succeeds for every other, to prove one bad
  # recipient cannot take the rest of the batch down with it.
  class FailingFor
    include Notifier

    class << self
      attr_accessor :failing_id
      attr_reader :delivered

      def reset!
        @delivered = []
        @failing_id = nil
      end
    end
    reset!

    def deliver(spam_report)
      if spam_report.id == self.class.failing_id
        raise Notifier::DeliveryError,
              "slack delivery failed: simulated outage"
      end

      self.class.delivered << spam_report.id
      "recording:#{spam_report.id}"
    end
  end

  # Reports itself as unconfigured, so the registry must fall back to :null.
  class Unconfigured
    include Notifier

    def configured?
      false
    end

    def deliver(_spam_report)
      raise "Unconfigured notifier must never be asked to deliver"
    end
  end
end
