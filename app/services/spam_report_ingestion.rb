# frozen_string_literal: true

# Turns one webhook payload into (at most) one SpamReport row and (at most) one
# queued notification.
#
# This is the only place that knows the ingestion rules, which keeps the
# controller a thin HTTP adapter and the model free of orchestration:
#
#   * replays of an event we already stored are recognised and never re-notified
#   * an unknown Type is a validation failure, not a 500
#   * notification is enqueued, never performed inline
class SpamReportIngestion
  Result = Struct.new(:report, :outcome, keyword_init: true) do
    def created?
      outcome == :created
    end

    def duplicate?
      outcome == :duplicate
    end

    def invalid?
      outcome == :invalid
    end

    def notification_enqueued?
      created? && report.spam_notification?
    end

    def error_message
      report.errors.full_messages.to_sentence
    end
  end

  def self.call(attributes)
    new(attributes).call
  end

  def initialize(attributes)
    @attributes = attributes.to_h.symbolize_keys
  end

  def call
    report = SpamReport.new(@attributes)
    return Result.new(report: report, outcome: :invalid) unless report.valid?

    existing = SpamReport.find_by(event_key: report.event_key)
    return Result.new(report: existing, outcome: :duplicate) if existing

    report.save!
    enqueue_notification(report)
    Result.new(report: report, outcome: :created)
  rescue ActiveRecord::RecordNotUnique
    # Two concurrent deliveries of the same event raced past the SELECT above.
    # The unique index is the real guard; fall back to whichever row won.
    winner = SpamReport.find_by(event_key: report.event_key)
    raise unless winner

    Result.new(report: winner, outcome: :duplicate)
  end

  private

  def enqueue_notification(report)
    return unless report.spam_notification?

    SpamNotificationJob.perform_later(report.id)
  end
end
