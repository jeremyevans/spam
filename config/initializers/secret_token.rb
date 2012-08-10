unless secret = ENV['SECRET_TOKEN']
  if File.exist?('config/secret_token.txt')
    secret = File.read('config/secret_token.txt')
  else
    raise StandardError, "cannot load secret token"
  end
end
Spam::Application.config.secret_token = secret
