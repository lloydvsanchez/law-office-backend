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

ActiveRecord::Schema[8.0].define(version: 2026_07_03_062656) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "vector"

  create_table "document_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id"
    t.uuid "created_by_id"
    t.uuid "updated_by_id"
    t.string "title", null: false
    t.string "description"
    t.string "practice_area"
    t.string "document_type"
    t.string "language"
    t.string "visibility"
    t.string "status"
    t.string "source"
    t.integer "current_version", default: 1
    t.text "content_raw"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_document_templates_on_created_by_id"
    t.index ["document_type"], name: "index_document_templates_on_document_type"
    t.index ["organization_id"], name: "index_document_templates_on_organization_id"
    t.index ["practice_area"], name: "index_document_templates_on_practice_area"
    t.index ["status"], name: "index_document_templates_on_status"
    t.index ["title"], name: "index_document_templates_on_title_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["updated_by_id"], name: "index_document_templates_on_updated_by_id"
  end

  create_table "embedding_providers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "adapter_key", null: false
    t.string "model", null: false
    t.jsonb "config", default: {}
    t.boolean "is_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "healthy", null: false
    t.integer "priority", default: 10, null: false
    t.integer "failure_threshold", default: 3, null: false
    t.integer "failure_count", default: 0, null: false
    t.text "last_error"
    t.datetime "last_used_at"
    t.datetime "last_checked_at"
    t.datetime "quota_resets_at"
    t.index ["adapter_key"], name: "index_embedding_providers_on_adapter_key"
    t.index ["is_enabled"], name: "index_embedding_providers_on_is_enabled"
    t.index ["priority"], name: "index_embedding_providers_on_priority"
    t.index ["status"], name: "index_embedding_providers_on_status"
    t.check_constraint "status::text = ANY (ARRAY['healthy'::character varying, 'rate_limited'::character varying, 'quota_exhausted'::character varying, 'unreachable'::character varying]::text[])", name: "chk_embedding_provider_status"
  end

  create_table "file_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "template_id"
    t.uuid "uploaded_by_id"
    t.string "original_filename"
    t.string "file_type"
    t.string "storage_url"
    t.string "ocr_status"
    t.text "extracted_text"
    t.bigint "file_size_bytes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["template_id"], name: "index_file_attachments_on_template_id"
    t.index ["uploaded_by_id"], name: "index_file_attachments_on_uploaded_by_id"
  end

  create_table "generation_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "template_id"
    t.uuid "llm_provider_id"
    t.uuid "generated_by_id"
    t.string "trigger_type"
    t.text "prompt_summary"
    t.integer "prompt_tokens"
    t.integer "completion_tokens"
    t.string "status"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["generated_by_id"], name: "index_generation_logs_on_generated_by_id"
    t.index ["llm_provider_id"], name: "index_generation_logs_on_llm_provider_id"
    t.index ["template_id"], name: "index_generation_logs_on_template_id"
  end

  create_table "llm_providers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "adapter_key"
    t.string "model"
    t.jsonb "config", default: {}
    t.boolean "is_enabled", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "healthy", null: false
    t.integer "priority", default: 10, null: false
    t.integer "failure_threshold", default: 3, null: false
    t.integer "failure_count", default: 0, null: false
    t.text "last_error"
    t.datetime "last_used_at"
    t.datetime "last_checked_at"
    t.datetime "quota_resets_at"
    t.index ["is_enabled"], name: "index_llm_providers_on_is_enabled"
    t.index ["priority"], name: "index_llm_providers_on_priority"
    t.index ["status"], name: "index_llm_providers_on_status"
    t.check_constraint "status::text = ANY (ARRAY['healthy'::character varying, 'rate_limited'::character varying, 'quota_exhausted'::character varying, 'unreachable'::character varying]::text[])", name: "chk_llm_provider_status"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "template_chunks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "document_template_id", null: false
    t.integer "chunk_index", null: false
    t.text "content", null: false
    t.vector "embedding", limit: 768
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_template_id", "chunk_index"], name: "index_template_chunks_on_document_template_id_and_chunk_index", unique: true
    t.index ["document_template_id"], name: "index_template_chunks_on_document_template_id"
    t.index ["embedding"], name: "index_template_chunks_on_embedding_hnsw", opclass: :vector_cosine_ops, using: :hnsw
  end

  create_table "template_clauses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "template_id"
    t.string "clause_key"
    t.string "label"
    t.text "content"
    t.string "clause_type"
    t.boolean "is_optional", default: false
    t.integer "sort_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["template_id"], name: "index_template_clauses_on_template_id"
  end

  create_table "template_court_levels", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "template_id", null: false
    t.string "court_level", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["template_id", "court_level"], name: "index_template_court_levels_unique", unique: true
    t.index ["template_id"], name: "index_template_court_levels_on_template_id"
  end

  create_table "template_tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "template_id", null: false
    t.string "tag", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag"], name: "index_template_tags_on_tag"
    t.index ["template_id", "tag"], name: "index_template_tags_unique", unique: true
    t.index ["template_id"], name: "index_template_tags_on_template_id"
  end

  create_table "template_variables", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "template_id"
    t.string "variable_key"
    t.string "label"
    t.string "data_type"
    t.boolean "is_required", default: false
    t.string "default_value"
    t.string "placeholder"
    t.integer "sort_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["template_id"], name: "index_template_variables_on_template_id"
  end

  create_table "template_versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "template_id"
    t.uuid "changed_by_id"
    t.integer "version_number"
    t.text "content_raw"
    t.string "change_summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["changed_by_id"], name: "index_template_versions_on_changed_by_id"
    t.index ["template_id"], name: "index_template_versions_on_template_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "name"
    t.string "email", null: false
    t.string "role"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "document_templates", "organizations"
  add_foreign_key "document_templates", "users", column: "created_by_id"
  add_foreign_key "document_templates", "users", column: "updated_by_id"
  add_foreign_key "file_attachments", "document_templates", column: "template_id"
  add_foreign_key "file_attachments", "users", column: "uploaded_by_id"
  add_foreign_key "generation_logs", "document_templates", column: "template_id"
  add_foreign_key "generation_logs", "llm_providers"
  add_foreign_key "generation_logs", "users", column: "generated_by_id"
  add_foreign_key "template_chunks", "document_templates"
  add_foreign_key "template_clauses", "document_templates", column: "template_id"
  add_foreign_key "template_court_levels", "document_templates", column: "template_id"
  add_foreign_key "template_tags", "document_templates", column: "template_id"
  add_foreign_key "template_variables", "document_templates", column: "template_id"
  add_foreign_key "template_versions", "document_templates", column: "template_id"
  add_foreign_key "template_versions", "users", column: "changed_by_id"
  add_foreign_key "users", "organizations"
end
