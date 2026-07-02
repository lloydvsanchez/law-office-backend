class AllowNullOrganizationIdToDocumentTemplates < ActiveRecord::Migration[8.0]
  def change
    change_column_null :document_templates, :organization_id, true
  end
end
