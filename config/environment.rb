$:.unshift "/data/code/sequel/lib"
require 'sequel/no_core_ext'
Sequel::Model.raise_on_typecast_failure = false
Sequel::Model.plugin :prepared_statements_safe
Sequel::Model.plugin :prepared_statements_associations
Sequel::Model.plugin :active_model

# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Spam::Application.initialize!

DB.optimize_model_load = true if DB.respond_to?(:optimize_model_load=)
DB.extension(:looser_typecasting)

require 'to_money'
require 'subset_sum'
require 'bcrypt'
