# frozen_string_literal: true

require "test_helper"

class SpamNotificationJobTest < ActiveSupport::TestCase
  setup do
    NotifierRegistry.register(:recording, "TestNotifiers::Recording")
    NotifierRegistry.register(:failing, "TestNotifiers::Failing")
    NotifierRegistry.register(:failing_for, "TestNotifiers::FailingFor")
  end

  test "delivers the report and records the receipt" do
    report = create_report

    SpamNotificationJob.perform_now(report.id, channel: :recording)

    assert_equal [report.id], TestNotifiers::Recording.deliveries
    report.reload

    assert_predicate report, :notified?
    assert_equal "recording:#{report.id}", report.notification_receipt
  end

  # Delivery correctness: the row is stamped only once the remote side has
  # accepted. A failed send must never leave a report looking delivered.
  test "a failed delivery does not mark the report notified" do
    report = create_report

    assert_enqueued_with(job: SpamNotificationJob) do
      SpamNotificationJob.perform_now(report.id, channel: :failing)
    end

    report.reload

    refute_predicate report, :notified?
    assert_nil report.notification_receipt
    assert_equal 1, report.notification_attempts
    assert_match(/simulated outage/, report.notification_error)
  end

  # Delivery correctness: the job is the retry target, so running it twice for
  # the same report must not produce a second alert.
  test "an already-notified report is a no-op" do
    report = create_report
    SpamNotificationJob.perform_now(report.id, channel: :recording)
    notified_at = report.reload.notified_at

    SpamNotificationJob.perform_now(report.id, channel: :recording)

    assert_equal [report.id], TestNotifiers::Recording.deliveries, "expected exactly one delivery"
    assert_equal notified_at, report.reload.notified_at
  end

  # Delivery correctness: one bad recipient must not abort the rest.
  test "one failing report does not stop the others from being delivered" do
    doomed = create_report(email: "doomed@example.com")
    healthy = [create_report(email: "a@example.com"), create_report(email: "b@example.com")]
    TestNotifiers::FailingFor.failing_id = doomed.id

    [doomed, *healthy].each do |report|
      SpamNotificationJob.perform_now(report.id, channel: :failing_for)
    rescue Notifier::DeliveryError
      nil
    end

    assert_equal healthy.map(&:id).sort, TestNotifiers::FailingFor.delivered.sort
    refute_predicate doomed.reload, :notified?
    healthy.each { |report| assert_predicate report.reload, :notified? }
  end

  test "a delivery failure is retried and only surfaces once the attempts run out" do
    report = create_report

    perform_enqueued_jobs(only: SpamNotificationJob) do
      assert_raises(Notifier::DeliveryError) do
        SpamNotificationJob.perform_now(report.id, channel: :failing)
      end
    end

    assert_equal 5, TestNotifiers::Failing.attempts.size, "expected the configured five attempts"
    report.reload

    refute_predicate report, :notified?
    assert_equal 5, report.notification_attempts
  end

  test "a report deleted before the job runs is a no-op" do
    report = create_report
    report.destroy!

    assert_nothing_raised { SpamNotificationJob.perform_now(report.id, channel: :recording) }
    assert_empty TestNotifiers::Recording.deliveries
  end

  test "falls back to the null notifier when Slack is not configured" do
    Rails.configuration.x.notifications.channel = :slack
    report = create_report

    assert_nothing_raised { SpamNotificationJob.perform_now(report.id) }
    assert_predicate report.reload, :notified?
    assert_equal "null:#{report.id}", report.notification_receipt
  end
end
