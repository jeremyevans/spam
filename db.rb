require 'sequel'

begin
  load File.join(File.dirname(__FILE__), 'db_config.rb')
rescue LoadError
  Spam::DB = Sequel.connect(ENV['SPAM_DATABASE_URL'] || ENV['DATABASE_URL'] || "postgres:///#{'spam_test' if ENV['RACK_ENV'] == 'test'}?user=spam", :identifier_mangling=>false)
end
