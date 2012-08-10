require File.expand_path('../boot', __FILE__)

require "action_controller/railtie"

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
#Bundler.require(:default, Rails.env) if defined?(Bundler)

module Spam
  class Application < Rails::Application
    config.filter_parameters = [:password]
    config.time_zone = 'UTC'
    config.logger = Logger.new($stdout) if ENV['STDOUT_LOGGER']
  end
end
