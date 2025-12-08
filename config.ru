require ::File.expand_path('../spam',  __FILE__)
run Spam::App.freeze.app

unless ENV['RACK_ENV'] == 'development'
  require 'tilt/sass' unless File.exist?(File.expand_path('../compiled_assets.json', __FILE__))
  Tilt.finalize!
  RubyVM::YJIT.enable if defined?(RubyVM::YJIT.enable)

  SPAM_CONFIG_RU_BEFORE_FREEZE.call if defined?(SPAM_CONFIG_RU_BEFORE_FREEZE)

  begin
    require 'refrigerator'
  rescue LoadError
  else
    Refrigerator.freeze_core
  end

  SPAM_CONFIG_RU.call if defined?(SPAM_CONFIG_RU)
end
