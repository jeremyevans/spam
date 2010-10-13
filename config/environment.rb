# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Spam::Application.initialize!

$:.unshift "/data/code/sequel/lib"
require 'sequel'
Sequel::Model.raise_on_typecast_failure = false
Sequel.extension :looser_typecasting
DB.extend(Sequel::LooserTypecasting)

require 'to_money'
require 'set'
require 'digest/sha1'
require 'subset_sum'
