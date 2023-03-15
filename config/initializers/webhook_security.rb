# frozen_string_literal: true

# The webhook endpoint triggers outbound Slack messages, so leaving it open in
# production is an invitation to have someone else's traffic fill your channel.
# Fail fast at boot rather than discovering it from the alert noise.
if Rails.env.production? && ENV["ALLOW_UNAUTHENTICATED_WEBHOOK"] != "true"
  missing = %w[WEBHOOK_USERNAME WEBHOOK_PASSWORD].reject { |key| ENV[key].present? }

  unless missing.empty?
    raise "Refusing to boot: #{missing.join(' and ')} not set. " \
          "Set them, or set ALLOW_UNAUTHENTICATED_WEBHOOK=true to accept an open endpoint."
  end
end
