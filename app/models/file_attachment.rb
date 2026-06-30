class FileAttachment < ApplicationRecord
    belongs_to :template,
               class_name: "DocumentTemplate"
  
    belongs_to :uploaded_by,
               class_name: "User"
end