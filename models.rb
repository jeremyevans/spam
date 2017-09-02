if File.exists?(File.expand_path('../.env.rb', __FILE__))
  require_relative '.env'
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

  require_relative 'db'

  DB.extension(:looser_typecasting)

  Model = Class.new(Sequel::Model)
  Model.db = DB
  Model.plugin :subclasses
  Model.plugin :forme
  Model.plugin :prepared_statements_safe
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
