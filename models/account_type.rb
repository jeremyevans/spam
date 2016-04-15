class AccountType < Sequel::Model
end

# Table: account_types
# Columns:
#  id   | integer | PRIMARY KEY DEFAULT nextval('account_types_id_seq'::regclass)
#  name | text    | NOT NULL
# Indexes:
#  account_types_pkey     | PRIMARY KEY btree (id)
#  account_types_name_key | UNIQUE btree (name)
# Referenced By:
#  accounts | accounts_account_type_id_fkey | (account_type_id) REFERENCES account_types(id)
