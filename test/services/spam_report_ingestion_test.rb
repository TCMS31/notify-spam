# frozen_string_literal: true

require "test_helper"

class SpamReportIngestionTest < ActiveSupport::TestCase
  test "stores a spam complaint and queues exactly one notification" do
    result = nil

    assert_difference -> { SpamReport.count }, 1 do
      assert_enqueued_jobs 1, only: SpamNotificationJob do
        result = SpamReportIngestion.call(report_attributes)
      end
    end

    assert_predicate result, :created?
    assert_predicate result, :notification_enqueued?
    assert_predicate result.report, :persisted?
  end

  test "stores a non-spam event without queueing a notification" do
    result = nil

    assert_difference -> { SpamReport.count }, 1 do
      assert_no_enqueued_jobs only: SpamNotificationJob do
        result = SpamReportIngestion.call(report_attributes(report_type: "HardBounce", type_code: 1))
      end
    end

    assert_predicate result, :created?
    refute_predicate result, :notification_enqueued?
  end

  test "a SpamNotification carrying a different type code is stored but not alerted on" do
    result = nil

    assert_no_enqueued_jobs only: SpamNotificationJob do
      result = SpamReportIngestion.call(report_attributes(type_code: 501))
    end

    assert_predicate result, :created?
  end

  # Delivery correctness: providers retry a webhook on any non-2xx response, so
  # the same event arrives repeatedly. It must never become a second row or a
  # second alert.
  test "a replayed webhook is recognised and neither stored nor alerted twice" do
    first = SpamReportIngestion.call(report_attributes)

    second = nil
    assert_no_difference -> { SpamReport.count } do
      assert_no_enqueued_jobs only: SpamNotificationJob do
        second = SpamReportIngestion.call(report_attributes)
      end
    end

    assert_predicate second, :duplicate?
    refute_predicate second, :notification_enqueued?
    assert_equal first.report.id, second.report.id
  end

  test "two events that differ in any identity field are both stored" do
    SpamReportIngestion.call(report_attributes)
    result = SpamReportIngestion.call(report_attributes(email: "second@example.com"))

    assert_predicate result, :created?
    assert_equal 2, SpamReport.count
  end

  test "an invalid payload is reported as invalid and stores nothing" do
    result = nil

    assert_no_difference -> { SpamReport.count } do
      assert_no_enqueued_jobs only: SpamNotificationJob do
        result = SpamReportIngestion.call(report_attributes(email: "not-an-email"))
      end
    end

    assert_predicate result, :invalid?
    assert_equal "Email is invalid", result.error_message
  end

  test "an unknown Type is invalid rather than raising" do
    result = nil

    assert_nothing_raised { result = SpamReportIngestion.call(report_attributes(report_type: "Nonsense")) }
    assert_predicate result, :invalid?
  end

  test "accepts string keys, as the middleware hands them over" do
    result = SpamReportIngestion.call(report_attributes.stringify_keys)

    assert_predicate result, :created?
  end

  # Simulates the race the unique index exists to win: the row lands between our
  # SELECT and our INSERT. The stub only hides the row from the first lookup;
  # the RecordNotUnique comes from the real Postgres index.
  test "loses the insert race gracefully and reports a duplicate" do
    winner = create_report
    original = SpamReport.method(:find_by)
    lookups = 0
    SpamReport.define_singleton_method(:find_by) do |*args, **options|
      lookups += 1
      lookups == 1 ? nil : original.call(*args, **options)
    end

    result = SpamReportIngestion.call(report_attributes)

    assert_predicate result, :duplicate?
    assert_equal winner.id, result.report.id
    assert_equal 1, SpamReport.count
  ensure
    SpamReport.singleton_class.send(:remove_method, :find_by)
  end
end
