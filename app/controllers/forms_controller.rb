require 'hpricot'

class FormsController < ApplicationController
  def index
    if !@admin_side
      display
      render :action => 'display'
    else
      admin_display
      render :action => 'admin_display'
    end
  end

  def display
    @form = FormsModule.find(params[:abstract_module_id] || @page.abstract_module_id)
    @fields = @form.forms_fields
    @required = false
    for field in @fields
      @required = true if field.required
    end
  end

  def submit
    if params[:form] && params[:form][:name]
      params.delete(:form)
    end
    
    values = params[:form] || extract_values_from_xml(request.env["RAW_POST_DATA"])
    # The fields that are either invalid or required and don't have values
    invalid = Array.new
    required = Array.new
    
    # default values for newsletter subscription
    newsletter = false
    email = ""
    tags = Array.new
    
    checkbox = false
    checkbox_value = false
    
    # Go through each value and check specific paramaters (required, valid, etc...)
    if values.blank?
      message = "You cannot submit a blank form"
      respond_to do |format|
        format.html {
          flash[:notice] = message
          display
          render :action => 'display'
        }
        format.js {
          render :update do |page|
            page.alert message
          end
        }
        format.xml {
          xmlout = ''
          xml = Builder::XmlMarkup.new(:indent => 2, :target => xmlout)
          xml.instruct!
          xml.response do
            xml.errors do
              xml.error(message)
            end
          end
          render :xml => xmlout
        }
      end
      return
    end
    values.each do |key, value|
      field = FormsField.find(key)
      
      # Is field valid according to specified validation?
      if !value.blank? && field.forms_validation
        if !(Regexp.new(field.forms_validation.regexp) === value)
          invalid << key
        end
      end

      # Is field required and do we have a value for it?
      if field.required && value.blank?
        required << key
      end
      
      # Checks for newsletter and if field is checkbox or label contains the word email
      if field.emc_tag && (field.forms_field_type.name == 'checkbox' || field.label =~ /e\-?mail/i)
        newsletter = true
        
        # Is the field a checkbox?  Needed later.
        if field.forms_field_type.name == 'checkbox'
          checkbox = true
          checkbox_value = value
        end
        tags << field
      end
      
      # Get email address if field label contains the word email.
      if field.label =~ /e\-?mail/i
        email = value
      end
    end
    
    if ((invalid.length > 0) || (required.length > 0))
      respond_to do |format|
        format.html {
          flash[:notice] = "There are invalid or missing fields, please correct them and submit again."
          display
          render :action => 'display'
        }
        format.js {
          render :update do |page|
            page.alert "There were invalid or missing fields, please correct them and submit again."
            invalid.each do |key|
              page.visual_effect :highlight, "field-" + key.to_s, 
                :startcolor => "'#FF0000'", :endcolor => "'#FFFFFF'", :duration => 10
            end
            required.each do |key|
              page.visual_effect :highlight, "field-" + key.to_s, 
                :startcolor => "'#FFFF00'", :endcolor => "'#FFFFFF'", :duration => 10
            end
          end
        }
        format.xml {
          xmlout = ''
          xml = Builder::XmlMarkup.new(:indent => 2, :target => xmlout)
          xml.instruct!
          xml.response do
            xml.errors do
              invalid.each do |key|
                xml.error(:field => key, :reason => 'Invalid') do
                  message
                end
              end
              required.each do |key|
                xml.error(:field => key, :reason => 'Required') do
                  message
                end
              end
            end
          end
          render :xml => xmlout
        }
      end
      return
    end
    
    forms_module = FormsModule.find(params[:abstract_module_id])
    
    # Does the form allow multiple submissions?
    # if !forms_module.allow_multi_sumbit
    #   # Has this user submitted this form before?
    #   if forms_module.forms_submitters.find(:first, :conditions => ['IP = ?', request.env["REMOTE_ADDR"]])
    #     render :update do |page|
    #       page.replace_html "content", "Sorry, but we have already received your submission and do not allow more than one at this time."
    #     end
    #     return
    #   end
    # end
    submitter = FormsSubmitter.new
    submitter.forms_module_id = params[:abstract_module_id]
    submitter.IP = request.env["REMOTE_ADDR"]
    submitter.save!
    
    values.each do |key, value|
      value = Date.new(value[:year].to_i, value[:month].to_i, value[:day].to_i) if value.kind_of? Hash
      FormsAnswer.create(:forms_field_id => key,
        :forms_submitter_id => submitter.id, :value => value)
    end
    
    if !(submitter.forms_module.recipient_email.blank? && submitter.forms_module.company.user.email.blank?)
      if submitter.forms_module.company.user.login == "yourstyle" &&
          submitter.forms_module.id == 80
        FormsMailer.deliver_your_style_financial_results(submitter, @company)
      else
        FormsMailer::deliver_form_results(submitter, @company)
      end
      
    end
    
    # Do we have a newsletter and email address?
    if newsletter && !email.empty?
      tags.each do |tag|
        # Does the label contain email and do we have a checkbox tag?  If so only submit if checkbox checked.
        if !checkbox
          logger.info "[Forms Controller] Subscribe #{email} to newsletter #{tag.emc_tag.id}"
          EmcEmailAddress::subscribe(email, tag.emc_tag)
        else
          logger.info "[Forms Controller] Subscribe #{email} to newsletter #{tag.emc_tag.id}"
          if !(tag.label =~ /e\-?mail/i) && checkbox_value == "Yes"
            EmcEmailAddress::subscribe(email, tag.emc_tag)
          end
        end
      end
    end
    
    # TEMPORARY WORK-AROUND for "Refer a friend" code that isn't written yet.
    
    your = (@company.user.email rescue '') # default
    admin = (@company.user.email rescue 'info@reflectionsdentalhealth.ca')
    friend_name = ''
    friend = ''
    your_name = ''
    if forms_module.id == 13 && forms_module.company_id == 8 && forms_module.name = 'Refer a Friend'
      values.each do |key, value|
        field = FormsField.find(key)
        if field.label =~ /^your friend\'?s name\:?/i
          friend_name = value
        end
        if field.label =~ /^your name\:?/i
          your_name = value
        end
        if field.label =~ /^your e\-?mail\:?/i
          your = value
        end
        if field.label =~ /^your friend's e\-?mail\:?/i
          friend = value
        end
      end    
      # mail sender
      if your
        GenericMailer.deliver_mail(:to => "#{your}", :from => "#{admin}", 
          :subject => "Thank you", 
          :body => "Thank you for referring a friend. For trusting in our services and recommending 
  them to someone you think could benefit from them, we have entered both of you in for a 
  draw to win dinner for two. If they become a client of ours, you will receive a small gift.

  #{forms_module.company.name}")
      end
      # mail recipient
      if friend
        if your.blank?
          your = admin
        end
        GenericMailer.deliver_mail(:to => "#{friend_name} <#{friend}>", :from => "#{your_name} <#{your}>", 
          :subject => forms_module.company.name, 
          :body => "Hi #{friend_name}, I thought you'd like to know about Reflections Dental Centre.

  You can find their website here: http://www.reflectionsdentalhealth.ca

  #{"Sincerely, \n" + your_name if your_name}")
      end
    end
    
    # END TEMPORARY WORK-AROUND
        
    message = submitter.forms_module.thank_you_content.blank? ? "Thank You For Your Submission!" : submitter.forms_module.thank_you_content

    respond_to do |format|
      format.html { 
        logger.info "[Forms Controller] Rendering HTML"
        render :text => message, :layout => true
      }
      format.js {
        logger.info "[Forms Controller] Rendering JS"
        render :update do |page|
          page.replace_html "form", message
          page.visual_effect :highlight, "form"
        end
      }
      format.xml {
        xmlout = ''
        xml = Builder::XmlMarkup.new(:indent => 2, :target => xmlout)
        xml.instruct!
        xml.response do
          xml.success do
            xml.thank_you_content do
              xml << message
            end
          end
        end
        logger.info "[Forms Controller] Rendering XML:\n#{xmlout}"
        render :xml => xmlout
      }
    end
  end
  
  # Admin methods!
  # 
  
  def view_submissions
    return unless @admin_side
    @forms_module = FormsModule.find(params[:abstract_module_id])
    @submitters = @forms_module.forms_submitters
    # add reply for xml?
  end
  
  def admin_display
    return unless @admin_side
    @forms_module = FormsModule.find(params[:abstract_module_id])
  end
  
  def popup_editor
    return unless @admin_side
    @field = params[:field]
    @forms_module = FormsModule.find(params[:abstract_module_id])
    render :layout => false
  end

  def new_field
    return unless @admin_side
    render :update do |page| 
      page.insert_html :bottom, 'forms_module', 
        render(:partial => 'forms_field_form', 
          :locals => {:forms_field => FormsField.new, :form_action => 'create'})
      page.visual_effect :blinddown, 'forms_field_new'
      page[:forms_field_label].focus
      page.sortable 'forms_module', :url => {:action => 'do_sort' }
    end
  end 
  
  def destroy
    return unless @admin_side
    @forms_field = FormsField.find(params[:id])
    id = @forms_field.id
    @forms_field.destroy
    render :update do |page|
      page.visual_effect :squish, "forms_field_#{id}"
      page.sortable 'forms_module', :url => {:action => 'do_sort' }
    end
  end
  
  def update
    return unless @admin_side
    @forms_field = FormsField.find(params[:id])
    render :update do |page|
      page.replace "forms_field_#{params[:id]}", 
        render(:partial => "forms_field_form", :locals => {:forms_field => @forms_field, :form_action => 'update'})
      page.visual_effect :highlight, "forms_field_#{params[:id]}"
      page.sortable 'forms_module', :url => {:action => 'do_sort' }
    end
  end
  
  def forms_field_update
    return unless @admin_side
    field_values = params[:field_values]
    @forms_field = FormsField.find(params[:id])
    if field_values && @forms_field.forms_fields_values.map(&:value).join("\n") != field_values
      @forms_field.forms_fields_values.clear
      field_values.each{|v|
        @forms_field.forms_fields_values.create(:value => v)
      }
    end
    if @forms_field.update_attributes(params[:forms_field])
      render :update do |page|
        page.replace "forms_field_#{params[:id]}", 
          render(:partial => 'forms_field', :locals => {:forms_field => @forms_field})
        page.visual_effect :highlight, "forms_field_#{params[:id]}"
        page.sortable "forms_module", :url => {:action => 'do_sort' }
      end
    end
  end
  
  def forms_field_create
    return unless @admin_side
    field_values = params[:field_values]
    field_values.gsub!("\n\n", "\n") # try to clean up input
    field_values = field_values.split("\n") if field_values
    @forms_field = FormsField.new(params[:forms_field])
    @forms_field.forms_module_id = params[:abstract_module_id]
    if field_values && @forms_field.forms_fields_values.map{|f| f.value.gsub("\n",'')}.join("\n") != field_values
      @forms_field.forms_fields_values.clear
      field_values.each{|v|
        @forms_field.forms_fields_values.create(:value => v.gsub("\n", '')) # extra gsub in case?
      }
    end
    if @forms_field.save
      render :update do |page|
        page.replace "forms_field_new", 
          render(:partial => 'forms_field', :locals => {:forms_field => @forms_field})
        page.visual_effect :highlight, "forms_field_#{@forms_field.id}"
        page.sortable "forms_module", :url => {:action => 'do_sort' }
      end
    else
      render :update do |page|
        page.alert "Couldn't create field!"
      end
    end
  end  
  
  def forms_field_show
    return unless @admin_side
    @forms_field = FormsField.find_by_id(params[:id])
    render :update do |page|
      if !@forms_field 
        page.visual_effect :DropOut, "forms_field_#{params[:id] || 'new'}"
      else
        page.replace "forms_field_#{params[:id] || 'new'}", 
          render(:partial => 'forms_field', :locals => {:forms_field => @forms_field})
        page.visual_effect :highlight, "forms_field_#{@forms_field.id}"
        page.sortable "forms_module", :url => {:action => 'do_sort' }
      end
    end
  end
  
  def do_sort
# "forms_module"=>["field_7", "field_8", "field_10", "field_22", "field_29", "field_30", "field_32", "field_31", "field_33", "field_34"]
    return unless @admin_side
    params[:forms_module].each_with_index do |id, position|
      # backwords compatibility; it doesn't work this way anymore.
      usable_id = id.include?('_') ? id.split('_')[1] : id

      FormsField.update(usable_id, :position => position)
    end
    render :nothing => true
  end
  
  def update_form
    return unless @admin_side
    forms_module = FormsModule.find(params[:abstract_module_id])
    if !(forms_module.update_attributes(params[:forms_module]))
      render :text => "There was a problem saving, please try again or contact support@clearlinewebsystems.ca"
      return
    end
  end
  
  def check_type
    render :update do |page|
      if params[:type] == "4" || params[:type] == "1"
        page.show params[:id] ? "newsletter_" + params[:id] : "newsletter_"
      else
        page.hide params[:id] ? "newsletter_" + params[:id] : "newsletter_"
      end
      
      if params[:type] == "2" || params[:type] == "3"
        page.show params[:id] ? "choices_" + params[:id] : "choices_"
      else
        page.hide params[:id] ? "choices_" + params[:id] : "choices_"
      end
      
      if params[:type] == '9'
        page.show params[:id] ? "description_" + params[:id] : "description_"
      else
        page.hide params[:id] ? "description_" + params[:id] : "description_"
      end
    end
  end
  
  private
  # handle xml passed in as parameters instead of normal stuff.
  # move this somewhere else eventually.
  # <form name="Contact"><field value="test" field_type="text" newsletter="" label="Name:" id="853" /><field value="test@test.ca" field_type="text" newsletter="" label="Email:" id="854" /><field field_type="textarea" newsletter="" label="Comments/Questions:" id="855">this is a test</field></form>
  def extract_values_from_xml(xml)
    if xml =~ /\<.*\>/
      x = Hpricot::XML(xml)
      new_hash = (x/"form/field").map {|field|
        {field[:id].to_s => (field[:value] || field.inner_text)}
      }.inject{|i, j| i.merge(j) }
      logger.info "Received XML body:\n#{xml}\nMapped to: #{new_hash}"
      new_hash
    end
  end
end
