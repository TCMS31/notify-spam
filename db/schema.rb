# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2023_03_15_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "spam_reports", force: :cascade do |t|
    t.string "record_type", null: false
    t.integer "report_type", null: false
    t.integer "type_code", null: false
    t.string "name", null: false
    t.string "tag"
    t.string "message_stream", null: false
    t.string "description", null: false
    t.string "email", null: false
    t.string "from", null: false
    t.datetime "bounced_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "event_key"
    t.datetime "notified_at", precision: nil
    t.string "notification_receipt"
    t.string "notification_error"
    t.integer "notification_attempts", default: 0, null: false
    t.index ["event_key"], name: "index_spam_reports_on_event_key", unique: true, where: "(event_key IS NOT NULL)"
    t.index ["notified_at"], name: "index_spam_reports_on_notified_at", where: "(notified_at IS NULL)"
    t.index ["report_type", "type_code", "bounced_at"], name: "index_spam_reports_on_report_type_and_type_code_and_bounced_at"
  end

end
