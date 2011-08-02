require File.expand_path('../boot', __FILE__)

require "action_controller/railtie"

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

module Spam
  class Application < Rails::Application
    config.encoding = "ISO-8859-1" if RUBY_VERSION >= '1.9'
    config.action_controller.default_charset = 'ISO-8859-1'
    config.filter_parameters = [:password]
    config.time_zone = 'UTC'
  end
end

