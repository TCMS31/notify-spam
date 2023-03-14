# frozen_string_literal: true

class AddNotificationTrackingToSpamReports < ActiveRecord::Migration[7.0]
  def change
    change_table :spam_reports, bulk: true do |t|
      # Idempotency key. Providers retry a webhook on any non-2xx response, so
      # the same event can arrive many times; the unique index makes a replay a
      # no-op instead of a duplicate row and a duplicate Slack alert.
      t.string :event_key

      # Delivery bookkeeping. notified_at is written only after the remote side
      # accepts the message, so "recorded" never runs ahead of "sent".
      t.datetime :notified_at
      t.string :notification_receipt
      t.string :notification_error
      t.integer :notification_attempts, null: false, default: 0
    end

    add_index :spam_reports, :event_key, unique: true, where: "event_key IS NOT NULL"
    # Supports the awaiting_notification sweep and any report filtered by type.
    add_index :spam_reports, %i[report_type type_code bounced_at]
    add_index :spam_reports, :notified_at, where: "notified_at IS NULL"
  end
end
