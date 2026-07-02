class GenerationLog < ApplicationRecord
    belongs_to :template,
               class_name: "DocumentTemplate"
  
    belongs_to :llm_provider
  
    belongs_to :generated_by,
               class_name: "User",
               optional: true
  
    enum :status,
         {
           pending: "pending",
           success: "success",
           failed: "failed"
         }
end