module Spam
class User < Sequel::Model(DB)
  def password=(new_password)
    self.password_hash = BCrypt::Password.create(new_password)
  end
end
end

# Table: users
# Columns:
#  id                   | integer | PRIMARY KEY DEFAULT nextval('users_id_seq'::regclass)
#  name                 | text    | NOT NULL
#  num_register_entries | integer | NOT NULL DEFAULT 35
#  password_hash        | text    | NOT NULL
# Indexes:
#  users_pkey     | PRIMARY KEY btree (id)
#  users_name_key | UNIQUE btree (name)
# Referenced By:
#  accounts | accounts_user_id_fkey | (user_id) REFERENCES users(id)
#  entities | entities_user_id_fkey | (user_id) REFERENCES users(id)
#  entries  | entries_user_id_fkey  | (user_id) REFERENCES users(id)
