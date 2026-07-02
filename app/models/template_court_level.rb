class TemplateCourtLevel < ApplicationRecord
    belongs_to :template,
              foreign_key: "template_id", 
              class_name: "DocumentTemplate"
  
    validates :court_level, presence: true
  
    enum :court_level,
         {
           first_level: "first_level",
           second_level: "second_level",
           appellate: "appellate",
           supreme: "supreme",
           quasi_judicial: "quasi_judicial"
         }
end