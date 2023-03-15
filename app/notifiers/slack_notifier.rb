# frozen_string_literal: true

# Posts a spam report to a Slack channel.
#
# The client is built lazily and injectable, so nothing here opens a socket at
# boot and tests can pass a double instead of reaching slack.com.
class SlackNotifier
  include Notifier

  def initialize(token: nil, channel: nil, client: nil)
    settings = Rails.configuration.x.notifications
    @token = token || settings.slack_token
    @channel = channel || settings.slack_channel
    @client = client
  end

  def configured?
    @token.present? && @channel.present?
  end

  def deliver(spam_report)
    response = client.chat_postMessage(channel: slack_channel, text: message_for(spam_report))
    "slack:#{response['ts'] || response[:ts]}"
  rescue Slack::Web::Api::Errors::SlackError, Faraday::Error => e
    raise Notifier::DeliveryError, "slack delivery failed: #{e.class}: #{e.message}"
  end

  private

  def message_for(spam_report)
    I18n.t("spam_report.notify",
           email: spam_report.email,
           type: spam_report.report_type,
           description: spam_report.description)
  end

  # Slack accepts both "#name" and a channel id; only prefix a bare name.
  def slack_channel
    @channel.start_with?("#", "C", "G") ? @channel : "##{@channel}"
  end

  def client
    @client ||= Slack::Web::Client.new(token: @token)
  end
end
