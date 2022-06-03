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

ActiveRecord::Schema[7.0].define(version: 2022_04_20_161434) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "audit_event_type", ["referral_broker_assignment", "referral_broker_reassignment", "element_ended", "element_cancelled", "element_suspended", "care_package_ended", "care_package_cancelled", "care_package_suspended", "referral_archived"]
  create_enum "element_cost_type", ["hourly", "daily", "weekly", "transport", "one_off"]
  create_enum "element_status", ["in_progress", "awaiting_approval", "approved", "inactive", "active", "ended", "suspended", "cancelled"]
  create_enum "provider_type", ["framework", "spot"]
  create_enum "referral_status", ["unassigned", "in_review", "assigned", "on_hold", "archived", "in_progress", "awaiting_approval", "approved", "active", "ended", "cancelled"]
  create_enum "user_role", ["brokerage_assistant", "broker", "approver", "care_charges_officer", "referrer"]
  create_enum "workflow_type", ["assessment", "review", "reassessment", "historic"]

  create_table "__EFMigrationsHistory", primary_key: "migration_id", id: { type: :string, limit: 150 }, force: :cascade do |t|
    t.string "product_version", limit: 32, null: false
  end

  create_table "audit_events", id: :integer, default: nil, force: :cascade do |t|
    t.text "social_care_id", null: false
    t.text "message", null: false
    t.enum "event_type", null: false, enum_type: "audit_event_type"
    t.text "metadata"
    t.datetime "created_at", precision: nil, null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "ix_audit_events_user_id"
  end

  create_table "dates", primary_key: "value", id: :date, force: :cascade do |t|
  end

  create_table "element_types", id: :integer, default: nil, force: :cascade do |t|
    t.integer "service_id", null: false
    t.text "name", null: false
    t.enum "cost_type", null: false, enum_type: "element_cost_type"
    t.boolean "non_personal_budget", default: false, null: false
    t.integer "position", null: false
    t.boolean "is_archived", default: false, null: false
    t.text "subjective_code"
    t.index ["service_id", "name"], name: "ix_element_types_service_id_name", unique: true
  end

  create_table "elements", id: :integer, default: nil, force: :cascade do |t|
    t.text "social_care_id", null: false
    t.integer "element_type_id", null: false
    t.boolean "non_personal_budget", null: false
    t.integer "provider_id", null: false
    t.text "details", null: false
    t.enum "internal_status", default: "in_progress", null: false, enum_type: "element_status"
    t.integer "parent_element_id"
    t.date "start_date", null: false
    t.date "end_date"
    t.jsonb "monday"
    t.jsonb "tuesday"
    t.jsonb "wednesday"
    t.jsonb "thursday"
    t.jsonb "friday"
    t.jsonb "saturday"
    t.jsonb "sunday"
    t.decimal "quantity"
    t.decimal "cost", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "cost_centre"
    t.virtual "daily_costs", type: :decimal, array: true, as: "ARRAY[COALESCE(((monday ->> 'Cost'::text))::numeric, (0)::numeric), COALESCE(((tuesday ->> 'Cost'::text))::numeric, (0)::numeric), COALESCE(((wednesday ->> 'Cost'::text))::numeric, (0)::numeric), COALESCE(((thursday ->> 'Cost'::text))::numeric, (0)::numeric), COALESCE(((friday ->> 'Cost'::text))::numeric, (0)::numeric), COALESCE(((saturday ->> 'Cost'::text))::numeric, (0)::numeric), COALESCE(((sunday ->> 'Cost'::text))::numeric, (0)::numeric)]", stored: true
    t.boolean "is_suspension", default: false, null: false
    t.integer "suspended_element_id"
    t.text "comment"
    t.index ["element_type_id"], name: "ix_elements_element_type_id"
    t.index ["parent_element_id"], name: "ix_elements_parent_element_id"
    t.index ["provider_id"], name: "ix_elements_provider_id"
    t.index ["suspended_element_id"], name: "ix_elements_suspended_element_id"
  end

  create_table "provider_services", primary_key: ["provider_id", "service_id"], force: :cascade do |t|
    t.integer "provider_id", null: false
    t.integer "service_id", null: false
    t.text "subjective_code"
    t.index ["service_id"], name: "ix_provider_services_service_id"
  end

  create_table "providers", id: :integer, default: nil, force: :cascade do |t|
    t.text "name", null: false
    t.text "address", null: false
    t.enum "type", null: false, enum_type: "provider_type"
    t.boolean "is_archived", default: false, null: false
    t.virtual "search_vector", type: :tsvector, as: "to_tsvector('simple'::regconfig, ((name || ' '::text) || address))", stored: true
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "cedar_number"
    t.index ["search_vector"], name: "ix_providers_search_vector", using: :gin
  end

  create_table "referral_elements", primary_key: ["element_id", "referral_id"], force: :cascade do |t|
    t.integer "referral_id", null: false
    t.integer "element_id", null: false
    t.index ["referral_id"], name: "ix_referral_elements_referral_id"
  end

  create_table "referrals", id: :integer, default: nil, force: :cascade do |t|
    t.text "workflow_id", null: false
    t.enum "workflow_type", null: false, enum_type: "workflow_type"
    t.text "social_care_id", null: false
    t.text "resident_name", null: false
    t.text "assigned_to"
    t.enum "status", null: false, enum_type: "referral_status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "urgent_since", precision: nil
    t.text "form_name", default: "", null: false
    t.text "note"
    t.text "primary_support_reason"
    t.datetime "started_at", precision: nil
    t.text "direct_payments"
    t.text "comment"
    t.index ["workflow_id"], name: "ix_referrals_workflow_id", unique: true
  end

  create_table "services", id: :integer, default: nil, force: :cascade do |t|
    t.integer "parent_id"
    t.text "name", null: false
    t.text "description"
    t.integer "position", null: false
    t.boolean "is_archived", default: false, null: false
    t.index ["parent_id"], name: "ix_services_parent_id"
  end

  create_table "users", id: :integer, default: nil, force: :cascade do |t|
    t.text "name", null: false
    t.text "email", null: false
    t.enum "roles", array: true, enum_type: "user_role"
    t.boolean "is_active", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "ix_users_email", unique: true
  end

  add_foreign_key "audit_events", "users", name: "fk_audit_events_users_user_id", on_delete: :cascade
  add_foreign_key "element_types", "services", name: "fk_element_types_services_service_id", on_delete: :cascade
  add_foreign_key "elements", "element_types", name: "fk_elements_element_types_element_type_id", on_delete: :cascade
  add_foreign_key "elements", "elements", column: "parent_element_id", name: "fk_elements_elements_parent_element_id", on_delete: :restrict
  add_foreign_key "elements", "elements", column: "suspended_element_id", name: "fk_elements_elements_suspended_element_id", on_delete: :restrict
  add_foreign_key "elements", "providers", name: "fk_elements_providers_provider_id", on_delete: :cascade
  add_foreign_key "provider_services", "providers", name: "fk_provider_services_providers_provider_id", on_delete: :cascade
  add_foreign_key "provider_services", "services", name: "fk_provider_services_services_service_id", on_delete: :cascade
  add_foreign_key "referral_elements", "elements", name: "fk_referral_elements_elements_element_id", on_delete: :cascade
  add_foreign_key "referral_elements", "referrals", name: "fk_referral_elements_referrals_referral_id", on_delete: :cascade
  add_foreign_key "services", "services", column: "parent_id", name: "fk_services_services_parent_id", on_delete: :restrict
end
