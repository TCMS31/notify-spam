# frozen_string_literal: true

# A single delivery event received from the mail provider's bounce webhook
# (Postmark's payload shape: RecordType/Type/TypeCode/Email/From/BouncedAt...).
#
# The model owns validation, the enum vocabulary and the notification bookkeeping
# columns. It deliberately does *not* send anything: ingestion is orchestrated by
# SpamReportIngestion and delivery happens in SpamNotificationJob, so a slow or
# failing Slack call can never take the HTTP request down with it.
class SpamReport < ApplicationRecord
  # Postmark uses TypeCode 512 for SpamNotification. Overridable because the
  # code is provider-specific, not a law of nature.
  SPAM_TYPE_CODE = Integer(ENV.fetch("SPAM_TYPE_CODE", 512))
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]{2,}\z/

  # Fields that make two webhook deliveries "the same event". Providers retry on
  # any non-2xx response, so without this a flaky Slack call would produce a
  # duplicate row and a duplicate alert on every retry.
  IDENTITY_ATTRIBUTES = %i[record_type report_type type_code email from bounced_at
                           message_stream description].freeze

  # The webhook calls this field "Type"; `type` is reserved by Active Record for
  # single-table inheritance, so it is stored as report_type and aliased back.
  alias_attribute :type, :report_type

  enum :report_type, { SpamNotification: 0, HardBounce: 1, SoftBounce: 2, Delivery: 3 }

  validates :record_type, :report_type, :type_code, :name, :message_stream,
            :description, :email, :from, :bounced_at, presence: true
  validates :email, :from, format: { with: EMAIL_FORMAT }, allow_blank: true
  # Computed, never supplied by the caller; a blank one would silently disable
  # replay detection, so treat it as a hard error.
  validates :event_key, presence: true
  validate :report_type_must_be_known

  before_validation :assign_event_key

  scope :spam_notifications, -> { where(report_type: :SpamNotification, type_code: SPAM_TYPE_CODE) }
  scope :awaiting_notification, -> { spam_notifications.where(notified_at: nil) }

  # Active Record raises ArgumentError for an unknown enum value, which surfaces
  # as a 500. Capture it and report it as an ordinary validation failure (422).
  def report_type=(value)
    @unknown_report_type = nil
    super
  rescue ArgumentError
    @unknown_report_type = value
    super(nil)
  end

  # True when this event is the one the product cares about: a spam complaint
  # carrying the provider's spam type code.
  def spam_notification?
    SpamNotification? && type_code == SPAM_TYPE_CODE
  end

  def notified?
    notified_at.present?
  end

  # Called only after the remote side has accepted the message, never before.
  # Bookkeeping columns deliberately bypass validations and callbacks: the row
  # is already stored and a stale validation must never block recording what
  # actually happened on the wire.
  # rubocop:disable Rails/SkipsModelValidations
  def mark_notified!(receipt: nil)
    update_columns(notified_at: Time.current, notification_receipt: receipt,
                   notification_error: nil, updated_at: Time.current)
  end

  def record_notification_failure!(error)
    update_columns(notification_error: error.message.to_s.truncate(500),
                   notification_attempts: notification_attempts.to_i + 1,
                   updated_at: Time.current)
  end
  # rubocop:enable Rails/SkipsModelValidations

  private

  def report_type_must_be_known
    return if @unknown_report_type.nil?

    # Drop the presence error the unknown value already caused.
    errors.delete(:report_type)
    known = self.class.report_types.keys.join(", ")
    errors.add(:report_type, "#{@unknown_report_type.inspect} is not a valid type (expected one of: #{known})")
  end

  def assign_event_key
    return if event_key.present?

    digest = IDENTITY_ATTRIBUTES.map { |attribute| public_send(attribute).to_s }.join(" ")
    self.event_key = OpenSSL::Digest::SHA256.hexdigest(digest)
  end
end
