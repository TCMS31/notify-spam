# frozen_string_literal: true

# Delivers the Slack alert for one spam report, out of band of the HTTP request.
#
# Delivery correctness rules encoded here:
#   * one job per report, so a failure for one report never stops another
#   * the report is marked notified *after* the remote side accepts, never before
#   * an already-notified report is a no-op, so retries and webhook replays cannot
#     produce a second alert
#   * only DeliveryError is retried; a NoMethodError in our own code fails loudly
class SpamNotificationJob < ApplicationJob
  queue_as :notifications

  retry_on Notifier::DeliveryError, wait: :exponentially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(spam_report_id, channel: nil)
    report = SpamReport.find_by(id: spam_report_id)
    return if report.nil?
    return if report.notified?

    receipt = NotifierRegistry.build(channel || NotifierRegistry.default_name).deliver(report)
    report.mark_notified!(receipt: receipt)
  rescue Notifier::DeliveryError => e
    report&.record_notification_failure!(e)
    raise
  end
end
