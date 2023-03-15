# frozen_string_literal: true

# Shared contract for outbound notification channels.
module Notifier
  # Raised when the remote service rejected or failed the delivery. The
  # notification job retries this and nothing else, so a bug in our own code
  # fails fast instead of being retried five times.
  class DeliveryError < StandardError
  end

  # True when the channel has everything it needs to deliver. A channel that is
  # not configured is swapped for NullNotifier rather than raising.
  def configured?
    true
  end

  # @param spam_report [SpamReport]
  # @return [String] an opaque receipt identifying the delivery
  def deliver(_spam_report)
    raise NotImplementedError, "#{self.class} must implement #deliver"
  end
end
