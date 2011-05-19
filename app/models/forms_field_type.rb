class FormsFieldType < ActiveRecord::Base
  has_many :forms_fields, :dependent => :nullify
end
