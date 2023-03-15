# frozen_string_literal: true

# Prints the Slack alert for the oldest stored spam complaint without sending
# anything: the real SlackNotifier runs against a recording double instead of
# its HTTP client.
#
#   bin/rails runner script/slack_preview.rb
class PrintingClient
  # Mirrors the one Slack::Web::Client method SlackNotifier calls.
  def chat_postMessage(channel:, text:) # rubocop:disable Naming/MethodName
    puts "chat.postMessage channel=#{channel}"
    puts "text:"
    puts(text.lines.map { |line| "  | #{line.chomp}" })
    { "ts" => "1678814979.000100" }
  end
end

report = SpamReport.spam_notifications.order(:id).first
abort "No spam complaints stored. Run bin/rails db:seed first." if report.nil?

receipt = SlackNotifier.new(token: "xoxb-not-a-real-token", channel: "email-alerts",
                            client: PrintingClient.new).deliver(report)
puts "receipt: #{receipt}"
