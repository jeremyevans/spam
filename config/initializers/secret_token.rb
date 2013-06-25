unless secret = ENV['SECRET_TOKEN']
  if File.exist?('config/secret_token.txt')
    secret = File.read('config/secret_token.txt')
  else
    raise StandardError, "cannot load secret token"
  end
end
Spam::Application.config.secret_token = secret

if Rails.version > '4'
  unless secret = ENV['SECRET_KEY_BASE']
    if File.exist?('config/secret_key_base.txt')
      secret = File.read('config/secret_key_base.txt')
    else
      raise StandardError, "cannot load secret key base"
    end
  end
  Spam::Application.config.secret_key_base = secret
end
