# frozen_string_literal: true

require "test_helper"

class SpamReportTest < ActiveSupport::TestCase
  test "a complete webhook payload is valid" do
    assert_predicate SpamReport.new(report_attributes), :valid?
  end

  test "every required field is required" do
    %i[record_type report_type type_code name message_stream description email from bounced_at].each do |field|
      report = SpamReport.new(report_attributes(field => nil))

      assert_predicate report, :invalid?, "expected #{field} to be required"
      assert_includes report.errors.attribute_names, field
    end
  end

  test "tag is optional" do
    assert_predicate SpamReport.new(report_attributes(tag: nil)), :valid?
  end

  test "email and from must look like addresses" do
    %w[not-an-email @example.com user@ user@example].each do |bad|
      assert_predicate SpamReport.new(report_attributes(email: bad)), :invalid?, "#{bad} should be rejected"
      assert_predicate SpamReport.new(report_attributes(from: bad)), :invalid?, "#{bad} should be rejected"
    end
  end

  # Regression: Active Record raises ArgumentError for an unknown enum value,
  # which used to escape the controller as a 500.
  test "an unknown Type is a validation error, not an ArgumentError" do
    report = nil

    assert_nothing_raised { report = SpamReport.new(report_attributes(report_type: "Nonsense")) }
    assert_predicate report, :invalid?
    assert_equal 1, report.errors[:report_type].size, "expected exactly one report_type error"
    assert_match(/"Nonsense" is not a valid type/, report.errors[:report_type].first)
    assert_match(/SpamNotification, HardBounce, SoftBounce, Delivery/, report.errors[:report_type].first)
  end

  test "the webhook's Type field is aliased onto report_type" do
    report = SpamReport.new(report_attributes.except(:report_type).merge(type: "HardBounce"))

    assert_equal "HardBounce", report.report_type
    assert_equal "HardBounce", report.type
  end

  test "spam_notification? requires both the SpamNotification type and the spam type code" do
    assert_predicate SpamReport.new(report_attributes(report_type: "SpamNotification", type_code: 512)),
                     :spam_notification?

    refute_predicate SpamReport.new(report_attributes(report_type: "SpamNotification", type_code: 501)),
                     :spam_notification?
    refute_predicate SpamReport.new(report_attributes(report_type: "HardBounce", type_code: 512)),
                     :spam_notification?
  end

  test "event_key is stable for the same event and different for a changed one" do
    first = SpamReport.new(report_attributes)
    same = SpamReport.new(report_attributes)
    other = SpamReport.new(report_attributes(email: "someone-else@example.com"))
    [first, same, other].each(&:valid?)

    assert_equal first.event_key, same.event_key
    refute_equal first.event_key, other.event_key
  end

  # Guards the guard: if the key ever stopped being computed, replay detection
  # would silently degrade to "everything is a duplicate of the first null row".
  test "a report without an idempotency key is invalid" do
    report = SpamReport.new(report_attributes)
    report.define_singleton_method(:assign_event_key) { nil }

    refute_predicate report, :valid?
    assert_includes report.errors.attribute_names, :event_key
  end

  test "the database refuses a second row with the same event_key" do
    first = create_report

    duplicate = SpamReport.new(report_attributes)
    duplicate.validate
    duplicate.event_key = first.event_key

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "mark_notified! stamps the delivery and clears any previous error" do
    report = create_report
    report.record_notification_failure!(StandardError.new("earlier outage"))

    report.mark_notified!(receipt: "slack:1678814979.000100")

    report.reload

    assert_predicate report, :notified?
    assert_equal "slack:1678814979.000100", report.notification_receipt
    assert_nil report.notification_error
  end

  test "record_notification_failure! counts attempts without marking the report notified" do
    report = create_report

    2.times { |i| report.record_notification_failure!(StandardError.new("outage #{i}")) }

    report.reload

    assert_equal 2, report.notification_attempts
    assert_equal "outage 1", report.notification_error
    refute_predicate report, :notified?
  end

  test "awaiting_notification finds only un-notified spam complaints" do
    pending = create_report
    create_report(email: "other@example.com").mark_notified!
    create_report(report_type: "HardBounce", type_code: 1, email: "bounce@example.com")

    assert_equal [pending.id], SpamReport.awaiting_notification.pluck(:id)
  end
end
