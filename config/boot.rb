env_file = File.expand_path('../../.env.rb', __FILE__)
if File.exists?(env_file)
  load(env_file)
end

require 'rubygems'
if RUBY_VERSION > '1.9'
  gem 'railties', '4.1.0'
  gem 'actionpack', '4.1.0'
else
  gem 'railties', '3.2.12'
  gem 'actionpack', '3.2.12'
end

# Set up gems listed in the Gemfile.
#ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

#require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
