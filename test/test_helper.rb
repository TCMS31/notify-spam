# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "webmock/minitest"

# Nothing in this suite may touch the network. If a change ever puts a live
# Slack call back on the ingestion path, these tests fail loudly instead of
# quietly posting into somebody's real channel.
WebMock.disable_net_connect!(allow_localhost: false)

Rails.root.glob("test/support/**/*.rb").each { |file| require file }

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    # A complete, valid Postmark-shaped webhook body in the provider's own
    # PascalCase. Tests override single keys rather than restating the payload.
    WEBHOOK_PAYLOAD = {
      "RecordType" => "Bounce",
      "Type" => "SpamNotification",
      "TypeCode" => 512,
      "Name" => "Spam notification",
      "Tag" => "welcome-email",
      "MessageStream" => "outbound",
      "Description" => "The recipient marked the message as spam.",
      "Email" => "recipient@example.com",
      "From" => "alerts@notify-spam.test",
      "BouncedAt" => "2023-03-14T17:29:39Z"
    }.freeze

    setup do
      NotifierRegistry.reset!
      Rails.configuration.x.notifications.channel = :null
      Rails.configuration.x.notifications.slack_token = nil
      Rails.configuration.x.notifications.slack_channel = nil
      TestNotifiers::Recording.reset!
      TestNotifiers::Failing.reset!
      TestNotifiers::FailingFor.reset!
    end

    # The provider's payload, in its own casing.
    def webhook_payload(overrides = {})
      WEBHOOK_PAYLOAD.merge(overrides.transform_keys(&:to_s))
    end

    # The same payload after SnakeCaseParams would have normalized it, for the
    # layers that sit below the middleware.
    def report_attributes(overrides = {})
      WEBHOOK_PAYLOAD.transform_keys(&:underscore).symbolize_keys.merge(overrides)
    end

    def create_report(overrides = {})
      SpamReport.create!(report_attributes(overrides))
    end

    def with_env(values)
      previous = values.keys.index_with { |key| ENV.fetch(key, nil) }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end
  end
end
