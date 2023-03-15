# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked, attempts: 3

  # A job whose record has since been deleted has nothing left to do.
  discard_on ActiveJob::DeserializationError
end
