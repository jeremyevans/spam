require 'digest/sha1'
class User < ActiveRecord::Base
  def self.login_user_id(username, password)
    return unless username && password
    return unless u = find_by_name(username)
    return unless u.password == Digest::SHA1.new(u.salt).update(password).hexdigest
    u.id
  end
  
  def password=(pass)
    self.salt = `openssl rand -hex 20`
    self[:password] = Digest::SHA1.new(salt).update(pass).hexdigest
  end
end
