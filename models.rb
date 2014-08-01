$: << '.'
$: << 'lib'

env_file = '.env.rb'
if File.exists?(env_file)
  load(env_file)
end

require 'rubygems'
require 'subset_sum'
require 'bcrypt'
require 'sequel'

if ENV['RACK_ENV'] == 'test'
  BCRYPT_COST = BCrypt::Engine::MIN_COST
else
  BCRYPT_COST = BCrypt::Engine::DEFAULT_COST
end

require File.join(File.dirname(__FILE__), 'db')

DB.extension(:looser_typecasting)

Sequel::Model.raise_on_typecast_failure = false
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

Dir['models/*'].each{|f| require f}

if ENV['RACK_ENV'] == 'development'
  require 'logger'
  DB.loggers << Logger.new($stdout)
end
