# frozen_string_literal: true
begin
  require_relative '.env'
rescue LoadError
end

require 'sequel'

module Spam
  opts = {}
  opts[:max_connections] = 1 if ENV['AJAX_TESTS'] == '1'
  DB = Sequel.connect(ENV.delete('SPAM_DATABASE_URL') || ENV.delete('DATABASE_URL') || "postgres:///#{'spam_test' if ENV['RACK_ENV'] == 'test'}?user=spam", opts)
  DB.extension(:looser_typecasting)
  DB.extension :pg_auto_parameterize
  DB.opts[:treat_string_list_as_untyped_array] = true
  DB.extension :pg_auto_parameterize_in_array
  if ENV['AJAX_TESTS'] == '1'
    DB.extension :temporarily_release_connection
  end
end
