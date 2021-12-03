require_relative 'db'

require 'subset_sum'
require 'bcrypt'

module Spam
  if ENV['RACK_ENV'] == 'test'
    BCRYPT_COST = BCrypt::Engine::MIN_COST
  else
    BCRYPT_COST = BCrypt::Engine::DEFAULT_COST
  end

  Model = Class.new(Sequel::Model)
  Model.db = DB
  Model.plugin :subclasses
  Model.plugin :forme
  Model.plugin :prepared_statements_safe
  Model.plugin :pg_auto_constraint_validations
  if ENV['UNUSED_ASSOCIATION_COVERAGE']
    Model.plugin :unused_associations, :coverage_file=>'unused_associations_coverage.json', :file=>'unused_associations.json'
  end
  if ENV['RACK_ENV'] == 'test'
    Model.plugin :forbid_lazy_load
    Model.plugin :instance_specific_default, :warn
  end
end

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

Dir[File.expand_path('../models/*', __FILE__)].each{|f| require_relative "models/#{File.basename(f)}"}

if ENV['RACK_ENV'] == 'development'
  require 'logger'
  Spam::DB.loggers << Logger.new($stdout)
else
  Spam::Model.freeze_descendents
  Spam::DB.freeze
end
