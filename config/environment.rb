RAILS_GEM_VERSION = '2.1.0'
require File.join(File.dirname(__FILE__), 'boot')

$:.unshift "/home/jeremy/sequel/lib"
require 'sequel'
Sequel::Model.typecast_on_assignment = false

Rails::Initializer.run do |config|
  config.frameworks -= [ :active_record, :active_resource, :action_mailer ]
  config.action_controller.session = { :session_key => "_myapp_session", :secret => "xEc6e4EN+Pce3WYxMeIhLNaqRTLkDV5lOfs9sCd0s/HbFHYVEgHMbA=="}
  config.action_controller.default_charset = 'ISO-8859-1'
end

ActionController::Base.param_parsers.delete(Mime::XML)
require 'scaffolding_extensions'
Sequel::Model::SCAFFOLD_OPTIONS[:text_to_string] = true
Sequel::Model::SCAFFOLD_OPTIONS[:association_list_class] = 'scaffold_associations_tree'
Sequel::Model::SCAFFOLD_OPTIONS[:auto_complete].merge!(:sql_name=>'name', :search_operator=>'ILIKE', :results_limit=>15, :phrase_modifier=>:to_s)
require 'to_money'
require 'set'
require 'digest/sha1'
require 'subset_sum'
