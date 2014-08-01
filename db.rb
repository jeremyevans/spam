require 'sequel'

begin
  load File.join(File.dirname(__FILE__), 'db_config.rb')
rescue LoadError
  DB = Sequel.connect(ENV['DATABASE_URL'] || "postgres:///#{'spam_test' if ENV['RACK_ENV'] == 'test'}?user=spam")
end
