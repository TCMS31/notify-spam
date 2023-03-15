# frozen_string_literal: true

# Shared-secret authentication for provider webhooks.
#
# Postmark (and most providers) let you embed HTTP Basic credentials in the
# webhook URL; that is the only authentication available for this kind of
# endpoint. Set WEBHOOK_USERNAME and WEBHOOK_PASSWORD to turn it on. With them
# unset the endpoint stays open, which keeps local development and the test
# suite friction-free — production.rb refuses to boot without them.
module WebhookAuthentication
  extend ActiveSupport::Concern

  included do
    # ActionController::API does not ship the HTTP Basic helpers.
    include ActionController::HttpAuthentication::Basic::ControllerMethods

    before_action :authenticate_webhook!
  end

  private

  def authenticate_webhook!
    return unless webhook_credentials_configured?

    denied = { message: "Invalid or missing webhook credentials" }.to_json

    authenticate_or_request_with_http_basic("Webhook", denied) do |username, password|
      secure_equal?(username,
                    ENV.fetch("WEBHOOK_USERNAME", nil)) & secure_equal?(password, ENV.fetch("WEBHOOK_PASSWORD", nil))
    end
  end

  def webhook_credentials_configured?
    ENV["WEBHOOK_USERNAME"].present? && ENV["WEBHOOK_PASSWORD"].present?
  end

  # Non-short-circuiting `&` above plus a fixed-length digest here keeps the
  # comparison time independent of how much of the secret the caller guessed.
  def secure_equal?(given, expected)
    ActiveSupport::SecurityUtils.secure_compare(
      OpenSSL::Digest::SHA256.hexdigest(given.to_s),
      OpenSSL::Digest::SHA256.hexdigest(expected.to_s)
    )
  end
end
