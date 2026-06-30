class TemplateClause < ApplicationRecord
    belongs_to :template,
               class_name: "DocumentTemplate"
end