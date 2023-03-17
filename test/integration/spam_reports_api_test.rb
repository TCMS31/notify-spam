# frozen_string_literal: true

require "test_helper"

class SpamReportsApiTest < ActionDispatch::IntegrationTest
  ENDPOINT = "/api/v1/spam_reports"

  test "accepts the provider's PascalCase payload and answers 201 with snake_case JSON" do
    assert_enqueued_jobs 1, only: SpamNotificationJob do
      post_webhook(webhook_payload)
    end

    assert_response :created
    assert_equal "application/json", response.media_type
    assert_equal "SpamNotification", body["report_type"]
    assert_equal "outbound", body["message_stream"]
    assert_equal "2023-03-14T17:29:39.000Z", body["bounced_at"]
    refute body["duplicate"]
    assert body["notification_enqueued"]
  end

  test "never leaks the idempotency key or delivery internals" do
    post_webhook(webhook_payload)

    assert_response :created
    %w[event_key notification_receipt notification_error].each do |hidden|
      refute_includes body.keys, hidden
    end
  end

  # Delivery correctness: the provider retries, so the same body will arrive
  # again. The second call must be a cheap acknowledgement, not a second alert.
  test "a replayed webhook answers 200 and queues nothing" do
    post_webhook(webhook_payload)
    first_id = body["id"]

    assert_no_enqueued_jobs only: SpamNotificationJob do
      post_webhook(webhook_payload)
    end

    assert_response :ok
    assert_equal first_id, body["id"]
    assert body["duplicate"]
    assert_equal 1, SpamReport.count
  end

  test "a non-spam event is stored without queueing an alert" do
    assert_no_enqueued_jobs only: SpamNotificationJob do
      post_webhook(webhook_payload("Type" => "HardBounce", "TypeCode" => 1))
    end

    assert_response :created
    assert_equal "HardBounce", body["report_type"]
  end

  # Regression: an unknown Type used to raise ArgumentError out of the enum
  # setter and return a 500 with an empty body.
  test "an unknown Type answers 422, not 500" do
    post_webhook(webhook_payload("Type" => "Nonsense"))

    assert_response :unprocessable_entity
    assert_match(/not a valid type/, body["message"])
    assert_equal 0, SpamReport.count
  end

  test "a missing required field answers 422 with the reason" do
    post_webhook(webhook_payload.except("Email"))

    assert_response :unprocessable_entity
    assert_match(/Email/, body["message"])
  end

  test "a malformed body answers 400 rather than crashing the middleware" do
    post ENDPOINT, params: "{not json", headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :bad_request
  end

  test "unknown fields in the payload are ignored rather than mass-assigned" do
    post_webhook(webhook_payload("Id" => 999, "NotifiedAt" => "2020-01-01T00:00:00Z"))

    assert_response :created
    refute_equal 999, body["id"]
    assert_nil body["notified_at"]
  end

  test "the endpoint is open when no webhook credentials are configured" do
    post_webhook(webhook_payload)

    assert_response :created
  end

  test "an unauthenticated call is rejected once credentials are configured" do
    with_env("WEBHOOK_USERNAME" => "postmark", "WEBHOOK_PASSWORD" => "s3cret") do
      post_webhook(webhook_payload)
    end

    assert_response :unauthorized
    assert_equal 0, SpamReport.count
  end

  test "wrong webhook credentials are rejected" do
    with_env("WEBHOOK_USERNAME" => "postmark", "WEBHOOK_PASSWORD" => "s3cret") do
      post_webhook(webhook_payload, headers: basic_auth("postmark", "guess"))
    end

    assert_response :unauthorized
    assert_equal 0, SpamReport.count
  end

  test "correct webhook credentials are accepted" do
    with_env("WEBHOOK_USERNAME" => "postmark", "WEBHOOK_PASSWORD" => "s3cret") do
      post_webhook(webhook_payload, headers: basic_auth("postmark", "s3cret"))
    end

    assert_response :created
  end

  private

  def post_webhook(payload, headers: {})
    post ENDPOINT, params: payload.to_json,
                   headers: { "CONTENT_TYPE" => "application/json" }.merge(headers)
  end

  def basic_auth(username, password)
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password) }
  end

  def body
    response.parsed_body
  end
end
