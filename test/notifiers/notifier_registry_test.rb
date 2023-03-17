# frozen_string_literal: true

require "test_helper"

class NotifierRegistryTest < ActiveSupport::TestCase
  test "ships with slack and null registered" do
    assert_includes NotifierRegistry.names, :slack
    assert_includes NotifierRegistry.names, :null
  end

  test "resolves a registered name to its class" do
    assert_equal SlackNotifier, NotifierRegistry.resolve(:slack)
    assert_equal NullNotifier, NotifierRegistry.resolve("null")
  end

  test "an unknown name raises with the list of known channels" do
    error = assert_raises(NotifierRegistry::UnknownNotifier) { NotifierRegistry.resolve(:carrier_pigeon) }

    assert_match(/carrier_pigeon/, error.message)
    assert_match(/slack/, error.message)
  end

  test "a new channel needs only a class and one register call" do
    NotifierRegistry.register(:recording, "TestNotifiers::Recording")

    assert NotifierRegistry.registered?(:recording)
    assert_instance_of TestNotifiers::Recording, NotifierRegistry.build(:recording)
  end

  test "build returns the requested notifier when it is configured" do
    Rails.configuration.x.notifications.slack_token = "xoxb-test"
    Rails.configuration.x.notifications.slack_channel = "alerts"

    assert_instance_of SlackNotifier, NotifierRegistry.build(:slack)
  end

  # Graceful degradation: with no credentials the app must still ingest events
  # rather than raising at boot or on every webhook.
  test "build falls back to the null notifier when the channel is unconfigured" do
    NotifierRegistry.register(:unconfigured, "TestNotifiers::Unconfigured")

    assert_instance_of NullNotifier, NotifierRegistry.build(:unconfigured)
    assert_instance_of NullNotifier, NotifierRegistry.build(:slack)
  end

  test "the default channel comes from configuration" do
    Rails.configuration.x.notifications.channel = :slack

    assert_equal :slack, NotifierRegistry.default_name
  end

  test "the Notifier contract refuses a notifier that forgot to implement deliver" do
    incomplete = Class.new { include Notifier }.new

    assert_raises(NotImplementedError) { incomplete.deliver(create_report) }
  end
end
