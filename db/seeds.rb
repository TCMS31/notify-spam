# frozen_string_literal: true

# Representative webhook events for local demos and screenshots. Idempotent:
# SpamReportIngestion recognises a replay, so re-running this adds nothing.
EVENTS = [
  { report_type: "SpamNotification", type_code: 512, name: "Spam notification",
    description: "The recipient marked the message as spam.", email: "annoyed@example.com" },
  { report_type: "SpamNotification", type_code: 512, name: "Spam notification",
    description: "Reported through the feedback loop.", email: "reporter@example.net" },
  { report_type: "HardBounce", type_code: 1, name: "Hard bounce",
    description: "The server was unable to deliver your message.", email: "gone@example.org" },
  { report_type: "SoftBounce", type_code: 4, name: "Soft bounce",
    description: "The mailbox is full.", email: "full@example.org" },
  { report_type: "Delivery", type_code: 0, name: "Delivery",
    description: "The message was delivered.", email: "happy@example.com" }
].freeze

EVENTS.each_with_index do |event, index|
  result = SpamReportIngestion.call(
    event.merge(record_type: "Bounce", tag: "welcome-email", message_stream: "outbound",
                from: "alerts@notify-spam.test", bounced_at: index.days.ago)
  )

  Rails.logger.info { "seed: #{event[:report_type]} -> #{result.outcome}" }
end
