class FormsAnswer < ActiveRecord::Base
  belongs_to :forms_submitter
  belongs_to :forms_field
  
  def parent_position
    self.forms_field.position unless self.forms_field.nil?
  end
end
