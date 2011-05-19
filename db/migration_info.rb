
  create_table "forms_answers", :force => true do |t|
    t.column "value",              :text
    t.column "forms_submitter_id", :integer
    t.column "forms_field_id",     :integer
  end

  create_table "forms_field_types", :force => true do |t|
    t.column "name", :string
  end

  create_table "forms_fields", :force => true do |t|
    t.column "label",               :string
    t.column "default_value",       :string
    t.column "required",            :boolean
    t.column "forms_module_id",     :integer
    t.column "forms_field_type_id", :integer
    t.column "position",            :integer
    t.column "forms_validation_id", :integer
    t.column "emc_tag_id",          :integer
    t.column "description",         :text
  end

  create_table "forms_fields_values", :force => true do |t|
    t.column "value",          :string
    t.column "forms_field_id", :integer
  end

  create_table "forms_modules", :force => true do |t|
    t.column "name",               :string
    t.column "allow_multi_sumbit", :boolean
    t.column "thank_you_content",  :text
    t.column "header_content",     :text
    t.column "recipient_email",    :string
    t.column "company_id",         :integer
    t.column "footer_content",     :text
  end

  create_table "forms_submitters", :force => true do |t|
    t.column "IP",              :string
    t.column "forms_module_id", :integer
    t.column "created_at",      :datetime
  end

  create_table "forms_validations", :force => true do |t|
    t.column "name",   :string
    t.column "regexp", :string
  end
