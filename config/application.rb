# frozen_string_literal: true

require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Loaded eagerly rather than autoloaded: the middleware stack is assembled
# before the autoloader is set up.
require_relative "../app/middlewares/snake_case_params"

module NotifySpam
  class Application < Rails::Application
    config.load_defaults 7.0

    # API-only: no views, helpers, assets, sessions, flash or cookies.
    config.api_only = true

    # Normalize the provider's PascalCase webhook keys into snake_case.
    config.middleware.use SnakeCaseParams

    # Slack delivery happens out of band of the request. The default :async
    # adapter keeps the app dependency-free; point ACTIVE_JOB_ADAPTER at a
    # durable backend (sidekiq, good_job, solid_queue) before relying on it.
    config.active_job.queue_adapter = ENV.fetch("ACTIVE_JOB_ADAPTER", "async").to_sym
  end
end
