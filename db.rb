begin
  require_relative '.env'
rescue LoadError
end

require 'sequel'

module Spam
  DB = Sequel.connect(ENV.delete('SPAM_DATABASE_URL') || ENV.delete('DATABASE_URL') || "postgres:///#{'spam_test' if ENV['RACK_ENV'] == 'test'}?user=spam")
  DB.extension(:looser_typecasting)
  DB.extension :pg_auto_parameterize
end
