class User < Sequel::Model
  def password=(new_password)
    self.password_hash = BCrypt::Password.create(new_password)
  end
end
