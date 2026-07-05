class AddHealthTrackingToProviders < ActiveRecord::Migration[8.0]
  def change
    # Apply identical columns to both provider tables
    [:llm_providers, :embedding_providers].each do |table|
      # Rename is_active to is_enabled to clarify it's admin-controlled
      rename_column table, :is_active, :is_enabled

      add_column table, :status,            :string,   default: "healthy", null: false
      add_column table, :priority,          :integer,  default: 10,        null: false
      add_column table, :failure_threshold, :integer,  default: 3,         null: false
      add_column table, :failure_count,     :integer,  default: 0,         null: false
      add_column table, :last_error,        :text
      add_column table, :last_used_at,      :datetime
      add_column table, :last_checked_at,   :datetime
      add_column table, :quota_resets_at,   :datetime

      add_index table, :status
      add_index table, :priority
      add_index table, :is_enabled, if_not_exists: true
    end

    # DB-level check constraints for status values
    execute <<~SQL
      ALTER TABLE llm_providers
      ADD CONSTRAINT chk_llm_provider_status
      CHECK (status IN ('healthy', 'rate_limited', 'quota_exhausted', 'unreachable'));

      ALTER TABLE embedding_providers
      ADD CONSTRAINT chk_embedding_provider_status
      CHECK (status IN ('healthy', 'rate_limited', 'quota_exhausted', 'unreachable'));
    SQL
  end
end
