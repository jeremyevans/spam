require 'rubygems'
if RUBY_VERSION > '1.9'
  gem 'railties', '4.0.0'
  gem 'actionpack', '4.0.0'
else
  gem 'railties', '3.2.12'
  gem 'actionpack', '3.2.12'
end

# Set up gems listed in the Gemfile.
#ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

#require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
