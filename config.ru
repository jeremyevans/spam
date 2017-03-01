require ::File.expand_path('../spam',  __FILE__)
use Rack::CommonLogger unless ENV['RACK_ENV'] == 'development'
run Spam::App.freeze.app
