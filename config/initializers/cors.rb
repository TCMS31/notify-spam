# frozen_string_literal: true

# This service is a server-to-server webhook receiver: the provider posts to it
# directly and no browser is involved, so the permissive `origins "*"` the
# generator ships with buys nothing. Keep CORS narrow and opt-in.
#
# Set CORS_ORIGINS to a comma-separated list to allow browser clients.
origins_list = ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)

if origins_list.any?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*origins_list)

      resource "/api/*", headers: :any, methods: %i[post options]
    end
  end
end
