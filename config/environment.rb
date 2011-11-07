$:.unshift "/data/code/sequel/lib"
require 'sequel'
Sequel::Model.raise_on_typecast_failure = false
Sequel.extension :looser_typecasting
Sequel::Model.plugin :prepared_statements_safe
Sequel::Model.plugin :prepared_statements_associations

# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Spam::Application.initialize!

DB.optimize_model_load = true
DB.extend(Sequel::LooserTypecasting)

require 'to_money'
require 'set'
require 'digest/sha1'
require 'subset_sum'
