require ::File.expand_path('../spam',  __FILE__)
run Spam::App.freeze.app

unless ENV['RACK_ENV'] == 'development'
  begin
    require 'refrigerator'
  rescue LoadError
  else
    require 'tilt/sass' unless File.exist?(File.expand_path('../compiled_assets.json', __FILE__))
    Refrigerator.freeze_core(:except=>['BasicObject'])
  end
end
