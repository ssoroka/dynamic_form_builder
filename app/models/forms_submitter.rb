class FormsSubmitter < ActiveRecord::Base
  belongs_to :forms_module
  has_many :forms_answers
  
  def sorted_forms_answers
    self.forms_answers.sort{|x,y| x.parent_position <=> y.parent_position}    
  end
end
