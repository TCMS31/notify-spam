# frozen_string_literal: true

module Api
  module V1
    # Receives bounce/spam webhooks from the mail provider. HTTP adapter only:
    # every rule lives in SpamReportIngestion.
    class SpamReportsController < ApplicationController
      include WebhookAuthentication

      PERMITTED_ATTRIBUTES = %i[record_type type type_code name tag message_stream
                                description email from bounced_at].freeze

      # POST /api/v1/spam_reports
      def create
        result = SpamReportIngestion.call(report_params.to_h)

        if result.invalid?
          render json: { message: result.error_message }, status: :unprocessable_entity
        else
          render json: serialize(result), status: result.duplicate? ? :ok : :created
        end
      end

      private

      def report_params
        params.permit(*PERMITTED_ATTRIBUTES)
      end

      def serialize(result)
        result.report
              .as_json(except: %i[event_key notification_receipt notification_error])
              .merge("duplicate" => result.duplicate?,
                     "notification_enqueued" => result.notification_enqueued?)
      end
    end
  end
end
