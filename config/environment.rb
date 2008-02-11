RAILS_GEM_VERSION = '2.0.2'
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  config.frameworks -= [ :active_resource, :action_mailer ]
  config.action_controller.session = { :session_key => "_myapp_session", :secret => "xEc6e4EN+Pce3WYxMeIhLNaqRTLkDV5lOfs9sCd0s/HbFHYVEgHMbA=="}
  config.action_controller.default_charset = 'ISO-8859-1'
end

ActionController::Base.param_parsers.delete(Mime::XML)
ActiveRecord::Base::SCAFFOLD_OPTIONS[:text_to_string] = true
ActiveRecord::Base::SCAFFOLD_OPTIONS[:association_list_class] = 'scaffold_associations_tree'
ActiveRecord::Base::SCAFFOLD_OPTIONS[:auto_complete].merge!({:sql_name=>'name', :text_field_options=>{:size=>80}, :search_operator=>'ILIKE', :results_limit=>15, :phrase_modifier=>:to_s})
require 'values_summing_to'
require 'set'

class BigDecimal
  def to_money
    "$%.02f" % self
  end
end

class Float
  def to_money
    "$%.02f" % self
  end
end

class String
  def to_money
    to_f.to_money
  end
end
