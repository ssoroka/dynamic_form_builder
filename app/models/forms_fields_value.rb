class FormsFieldsValue < ActiveRecord::Base
  belongs_to :forms_field

  def as_xml(xml = nil, options = {:indent => 2})
    if xml.nil?
      xml = Builder::XmlMarkup.new(options)
      xml.instruct!
    end

    xml.field_value(:id => id, :value => value)
    xml
  end
end
