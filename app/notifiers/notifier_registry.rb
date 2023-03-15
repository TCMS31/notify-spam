# frozen_string_literal: true

# Extension seam for outbound channels.
#
# A notifier is any object that responds to `deliver(spam_report)` and raises
# Notifier::DeliveryError when the remote end rejects the message. Adding a
# channel (email, PagerDuty, an internal webhook) means writing that one class
# and registering it:
#
#   NotifierRegistry.register(:pagerduty, "PagerdutyNotifier")
#
# Classes are registered by name and resolved lazily so registration can happen
# from an initializer without fighting Zeitwerk's autoloader.
class NotifierRegistry
  class UnknownNotifier < KeyError
  end

  BUILTIN = { slack: "SlackNotifier", null: "NullNotifier" }.freeze

  class << self
    def register(name, class_name)
      registry[name.to_sym] = class_name.to_s
    end

    def names
      registry.keys
    end

    def registered?(name)
      registry.key?(name.to_sym)
    end

    # Resolves and instantiates a notifier. Falls back to the null notifier when
    # the requested channel is present but not configured, so an unconfigured
    # deployment degrades to "record but do not notify" instead of crashing.
    def build(name = default_name)
      notifier = resolve(name).new
      return notifier if notifier.configured?

      Rails.logger.warn("[notifications] #{name} is not configured; falling back to :null")
      resolve(:null).new
    end

    def resolve(name)
      class_name = registry.fetch(name.to_sym) do
        raise UnknownNotifier, "unknown notifier #{name.inspect} (known: #{names.join(', ')})"
      end
      class_name.constantize
    end

    def default_name
      Rails.configuration.x.notifications.channel || :null
    end

    def reset!
      @registry = BUILTIN.dup
    end

    private

    def registry
      @registry ||= BUILTIN.dup
    end
  end
end
