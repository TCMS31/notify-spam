# frozen_string_literal: true

require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "reports ok when the database answers" do
    get "/up"

    assert_response :success
    assert_equal "ok", response.parsed_body["status"]
    assert_equal "ok", response.parsed_body["database"]
  end

  test "reports unavailable when the database does not answer" do
    ActiveRecord::Base.connection.stub(:execute, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
      get "/up"
    end

    assert_response :service_unavailable
    assert_equal "error", response.parsed_body["status"]
  end

  # The probe must not depend on Slack: a notification outage should not pull
  # the container out of rotation.
  test "does not touch the notification provider" do
    get "/up"

    assert_response :success
    assert_not_requested(:any, /slack\.com/)
  end
end
