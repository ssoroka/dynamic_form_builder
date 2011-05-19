class FormsMailer < ActionMailer::Base
  def form_results(submitter, company)
    @recipients = submitter.forms_module.recipient_email
    @recipients = company.user.email if @recipients.blank?
    
    @from = @recipients.split(',').first.split(';').first # just in case more than one.
    @subject = "Response for #{submitter.forms_module.name}"
    @body = { :submitter => submitter }
  end

  def your_style_financial_results(submitter, company)
    @recipients = submitter.forms_module.recipient_email
    @recipients = company.user.email if @recipients.blank?
    
    @from = company.user.email
    @subject = "Response for #{submitter.forms_module.name}"
    @body = { :submitter => submitter }
  end
end
