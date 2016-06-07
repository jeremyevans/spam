env_file = File.expand_path('../.env.rb', __FILE__)
if File.exists?(env_file)
  load(env_file)
end

require 'rubygems'
require 'subset_sum'
require 'bcrypt'
require 'sequel'

module Spam
  if ENV['RACK_ENV'] == 'test'
    BCRYPT_COST = BCrypt::Engine::MIN_COST
  else
    BCRYPT_COST = BCrypt::Engine::DEFAULT_COST
  end
end

require File.expand_path('../db', __FILE__)

Spam::DB.extension(:looser_typecasting)

Sequel::Model.plugin :prepared_statements_safe
Sequel::Model.plugin :prepared_statements_associations

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

Dir[File.expand_path('../models/*', __FILE__)].each{|f| require f}

if ENV['RACK_ENV'] == 'development'
  require 'logger'
  Spam::DB.loggers << Logger.new($stdout)
end
