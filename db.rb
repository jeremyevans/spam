require 'sequel'

begin
  require_relative 'db_config'
rescue LoadError
  Spam::DB = Sequel.connect(ENV['SPAM_DATABASE_URL'] || ENV['DATABASE_URL'] || "postgres:///#{'spam_test' if ENV['RACK_ENV'] == 'test'}?user=spam")
end
