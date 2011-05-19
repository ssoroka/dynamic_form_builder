class FormsField < ActiveRecord::Base
  has_many :forms_fields_values, :dependent => :destroy
  has_many :forms_answers, :dependent => :destroy
  belongs_to :forms_field_type
  belongs_to :forms_module
  belongs_to :forms_validation
  belongs_to :emc_tag
  
  acts_as_list :scope => :forms_module

  def as_xml(xml = nil, options = {:indent => 2})
    if xml.nil?
      xml = Builder::XmlMarkup.new(options)
      xml.instruct!
    end

    xml.field(:id => id, :label => label, :default_value => default_value,
      :required => required, :field_type => (forms_field_type.name rescue ''),
      :position => position, :newsletter => (emc_tag.name rescue '')) {
        if forms_validation
          xml.validation(:name => forms_validation.name, :regexp => forms_validation.regexp)
        end
        xml.description(description)
        forms_fields_values.each{|fval|
          xml = fval.as_xml(xml)  
        }
    }
    xml
  end
end
