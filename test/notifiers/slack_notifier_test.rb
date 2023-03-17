# frozen_string_literal: true

require "test_helper"

# These tests drive the real slack-ruby-client through WebMock, so the HTTP
# request the app would actually make is asserted without a byte leaving the
# machine. WebMock.disable_net_connect! in test_helper is what guarantees that.
class SlackNotifierTest < ActiveSupport::TestCase
  POST_MESSAGE_URL = "https://slack.com/api/chat.postMessage"

  test "is unconfigured without both a token and a channel" do
    refute_predicate SlackNotifier.new(token: nil, channel: "alerts"), :configured?
    refute_predicate SlackNotifier.new(token: "xoxb-test", channel: nil), :configured?
    assert_predicate SlackNotifier.new(token: "xoxb-test", channel: "alerts"), :configured?
  end

  test "posts the templated alert and returns the Slack timestamp as a receipt" do
    stub_post_message
    report = create_report

    receipt = SlackNotifier.new(token: "xoxb-test", channel: "alerts").deliver(report)

    assert_equal "slack:1678814979.000100", receipt
    assert_requested(:post, POST_MESSAGE_URL) do |request|
      body = Rack::Utils.parse_nested_query(request.body)

      assert_equal "#alerts", body["channel"]
      assert_includes body["text"], report.email
      assert_includes body["text"], report.description
      assert_includes body["text"], "SpamNotification"
      true
    end
  end

  test "leaves an explicit channel id alone and prefixes a bare channel name" do
    stub_post_message
    report = create_report

    SlackNotifier.new(token: "xoxb-test", channel: "C01234567").deliver(report)
    assert_requested(:post, POST_MESSAGE_URL) { |req| Rack::Utils.parse_nested_query(req.body)["channel"] == "C01234567" }

    SlackNotifier.new(token: "xoxb-test", channel: "#already-hashed").deliver(report)
    assert_requested(:post, POST_MESSAGE_URL) do |req|
      Rack::Utils.parse_nested_query(req.body)["channel"] == "#already-hashed"
    end
  end

  test "a Slack API error becomes a DeliveryError so the job can retry it" do
    stub_request(:post, POST_MESSAGE_URL)
      .to_return(status: 200, body: { ok: false, error: "channel_not_found" }.to_json,
                 headers: { "Content-Type" => "application/json" })

    error = assert_raises(Notifier::DeliveryError) do
      SlackNotifier.new(token: "xoxb-test", channel: "alerts").deliver(create_report)
    end

    assert_match(/slack delivery failed/, error.message)
  end

  test "a transport failure becomes a DeliveryError too" do
    stub_request(:post, POST_MESSAGE_URL).to_timeout

    assert_raises(Notifier::DeliveryError) do
      SlackNotifier.new(token: "xoxb-test", channel: "alerts").deliver(create_report)
    end
  end

  test "reads its credentials from configuration when none are injected" do
    Rails.configuration.x.notifications.slack_token = "xoxb-from-config"
    Rails.configuration.x.notifications.slack_channel = "from-config"

    assert_predicate SlackNotifier.new, :configured?
  end

  private

  def stub_post_message
    stub_request(:post, POST_MESSAGE_URL)
      .to_return(status: 200,
                 body: { ok: true, ts: "1678814979.000100", channel: "C01234567" }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end
end
