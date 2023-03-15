# frozen_string_literal: true

# Outbound-notification configuration.
#
# Nothing here talks to a network. The Slack client is built lazily by
# SlackNotifier the first time a notification is actually delivered, so the
# application boots (and the test suite runs) with no credentials present.
Rails.application.configure do
  config.x.notifications.channel = ENV.fetch("NOTIFIER", "slack").to_sym
  config.x.notifications.slack_token = ENV["SLACK_API_TOKEN"].presence
  config.x.notifications.slack_channel = ENV["SLACK_CHANNEL_NAME"].presence
end
