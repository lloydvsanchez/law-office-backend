class TemplateTag < ApplicationRecord
    belongs_to :template,
               class_name: "DocumentTemplate"
  end