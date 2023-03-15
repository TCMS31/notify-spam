# frozen_string_literal: true

# Liveness probe for the container and the load balancer. It checks the one
# dependency the app cannot serve without — the database — and deliberately does
# not touch Slack, so an outage at the notification provider never takes the
# whole service out of rotation.
class HealthController < ApplicationController
  def show
    ActiveRecord::Base.connection.execute("SELECT 1")
    render json: { status: "ok", database: "ok" }
  rescue StandardError => e
    render json: { status: "error", database: e.class.name }, status: :service_unavailable
  end
end
