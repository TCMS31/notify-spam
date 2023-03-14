# frozen_string_literal: true

class CreateSpamReports < ActiveRecord::Migration[7.0]
  def change
    create_table :spam_reports do |t|
      t.string :record_type, null: false
      t.integer :report_type, null: false
      t.integer :type_code, null: false
      t.string :name, null: false
      t.string :tag
      t.string :message_stream, null: false
      t.string :description, null: false
      t.string :email, null: false
      t.string :from, null: false
      t.datetime :bounced_at, null: false

      t.timestamps
    end
  end
end
