class TemplateVariable < ApplicationRecord
    belongs_to :template,
               class_name: "DocumentTemplate"
  
    enum :data_type,
         {
           string: "string",
           integer: "integer",
           float: "float",
           boolean: "boolean",
           date: "date",
           text: "text"
         }
end