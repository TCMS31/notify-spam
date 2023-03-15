# frozen_string_literal: true

class ApplicationController < ActionController::API
  # The webhook body is a flat event, not a nested resource. Without this Rails
  # would also copy every key under a "spam_report" root and then log each one
  # as an unpermitted parameter.
  wrap_parameters false

  # A provider that posts a truncated or malformed body should get a clear 400
  # with a JSON body, not an empty 500 from deep inside Rack.
  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render json: { message: "Request body could not be parsed as JSON" }, status: :bad_request
  end
end
