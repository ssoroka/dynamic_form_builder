class FormsModule < ActiveRecord::Base
  belongs_to :company
  has_many :forms_submitters, :dependent => :destroy
  has_many :forms_fields, :order => 'position', :dependent => :destroy
  
  def as_xml(xml = nil, options = {:indent => 2})
    if xml.nil?
      xml = Builder::XmlMarkup.new(options)
      xml.instruct!
    end

    xml.module(:type => self.class.name, :name => name, :id => id){
      xml.header_content do
        xml << header_content.to_s
      end
      xml.footer_content do
        xml << footer_content.to_s
      end
      # xml.thank_you_content(self.thank_you_content)
      self.forms_fields.each {|field|
        xml = field.as_xml(xml)
      }
    }
    xml
  end
  
  def submissions_xml(options = {})
    xml = Builder::XmlMarkup.new({:indent => 2}.merge(options))
    xml.instruct!
    xml.submissions do
      @submitters.each{|submitter|
        xml.submitter(:id => submitter.id) do
          xml.created_at(submitter.created_at) if submitter.respond_to?(:created_at) && !submitter.created_at.nil?
          xml.ip(submitter.IP)
          xml.answers do
            submitter.forms_answers.each{ |fa|
              xml.answer do
                # double (()) needed
                xml.label((fa.forms_field.label rescue "[Missing?]"))
                xml.value(fa.value)
              end
            }
        end
        end
      }
    end
    xml
  end
end
