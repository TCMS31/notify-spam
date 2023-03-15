# frozen_string_literal: true

Rails.application.routes.draw do
  # Container/load-balancer liveness probe.
  get "up", to: "health#show"

  namespace :api do
    namespace :v1 do
      resources :spam_reports, only: :create
    end
  end
end
