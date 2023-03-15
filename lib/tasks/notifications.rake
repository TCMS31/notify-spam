# frozen_string_literal: true

namespace :notifications do
  desc "Re-queue spam complaints that were never successfully notified"
  task sweep: :environment do
    pending = SpamReport.awaiting_notification.order(:id)
    pending.find_each { |report| SpamNotificationJob.perform_later(report.id) }

    puts "queued #{pending.count} pending notification(s)"
  end
end
