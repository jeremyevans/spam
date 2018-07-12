require ::File.expand_path('../spam',  __FILE__)
use Rack::CommonLogger unless ENV['RACK_ENV'] == 'development'
run Spam::App.freeze.app

begin
  require 'refrigerator'
rescue LoadError
else
  require 'tilt/sass' unless File.exist?(File.expand_path('../compiled_assets.json', __FILE__))
  Refrigerator.freeze_core(:except=>['BasicObject'])
end
