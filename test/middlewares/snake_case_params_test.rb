# frozen_string_literal: true

require "test_helper"

class SnakeCaseParamsTest < ActiveSupport::TestCase
  test "rewrites PascalCase body keys into snake_case" do
    params = call_middleware(body: { "RecordType" => "Bounce", "TypeCode" => 512 }.to_json)

    assert_equal %w[record_type type_code], params.keys.sort
    assert_equal "Bounce", params["record_type"]
  end

  test "rewrites nested objects and objects inside arrays" do
    body = { "Outer" => { "InnerKey" => 1 }, "Items" => [{ "ItemName" => "x" }] }.to_json

    params = call_middleware(body: body)

    assert_equal({ "inner_key" => 1 }, params["outer"])
    assert_equal([{ "item_name" => "x" }], params["items"])
  end

  test "leaves values untouched" do
    params = call_middleware(body: { "Description" => "Marked As Spam" }.to_json)

    assert_equal "Marked As Spam", params["description"]
  end

  test "rewrites query-string keys too" do
    params = call_middleware(body: "{}", query: "MessageStream=outbound")

    assert_equal "outbound", params["message_stream"]
  end

  # Regression: an unparsable body used to raise out of the middleware, before
  # Rails had a chance to turn it into a 400.
  test "a malformed body is passed through instead of raising" do
    assert_nothing_raised { call_middleware(body: "{not json", parse: false) }
  end

  private

  # Runs the middleware over a synthetic request and returns the parameters the
  # application would have seen.
  def call_middleware(body:, query: "", parse: true)
    seen = nil
    app = lambda do |env|
      request = ActionDispatch::Request.new(env)
      seen = parse ? request.request_parameters.merge(request.query_parameters) : {}
      [200, {}, ["ok"]]
    end

    env = Rack::MockRequest.env_for("/api/v1/spam_reports?#{query}",
                                    method: "POST", input: body,
                                    "CONTENT_TYPE" => "application/json",
                                    # Without a logger in env, ActionDispatch falls
                                    # back to $stderr and pollutes the test output.
                                    "action_dispatch.logger" => Logger.new(File::NULL))
    SnakeCaseParams.new(app).call(env)
    seen
  end
end
