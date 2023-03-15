# frozen_string_literal: true

# Swallows notifications. Used when no channel is configured (local development,
# CI) so that ingestion still works end to end without credentials.
class NullNotifier
  include Notifier

  def deliver(spam_report)
    Rails.logger.info("[notifications] suppressed notification for SpamReport##{spam_report.id}")
    "null:#{spam_report.id}"
  end
end
