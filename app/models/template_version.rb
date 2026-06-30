class TemplateVersion < ApplicationRecord
    belongs_to :template,
               class_name: "DocumentTemplate"
  
    belongs_to :changed_by,
               class_name: "User"
end