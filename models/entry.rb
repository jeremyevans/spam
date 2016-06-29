module Spam
class Entry < Model
  many_to_one :credit_account, :class_name=>'Spam::Account', :key=>:credit_account_id, :reciprocal=>:credit_entries
  many_to_one :debit_account, :class_name=>'Spam::Account', :key=>:debit_account_id, :reciprocal=>:debit_entries
  many_to_one :entity, :reciprocal=>:entries
  
  def self.user(user_id)
    filter(:user_id=>user_id)
  end

  dataset_module do
    def with_account(account_id)
      filter(account_id=>[:credit_account_id, :debit_account_id])
    end
  end
  
  def scaffold_name
    "#{date.strftime('%Y-%m-%d')}-#{reference}-#{entity.name if entity}-#{debit_account.name if debit_account}-#{credit_account.name if credit_account}-#{money_amount}"
  end

  def entity_name
    entity.name if entity
  end
  
  attr_accessor :other_account
  
  def money_amount
    amount.to_money
  end
  
  def main_account=(account)
    @other_account = if account.id == credit_account_id
      self[:amount] *= -1 if amount
      debit_account
    else
      credit_account
    end
  end
end
end

# Table: entries
# Columns:
#  id                | integer       | PRIMARY KEY DEFAULT nextval('entries_id_seq'::regclass)
#  debit_account_id  | integer       | NOT NULL
#  credit_account_id | integer       | NOT NULL
#  entity_id         | integer       |
#  reference         | text          |
#  date              | date          | DEFAULT ('now'::text)::date
#  amount            | numeric(10,2) | NOT NULL
#  cleared           | boolean       | DEFAULT false
#  memo              | text          |
#  user_id           | integer       | NOT NULL
# Indexes:
#  entries_pkey      | PRIMARY KEY btree (id)
#  entries_user_date | btree (user_id, date)
# Check constraints:
#  entries_amount_check | (amount > 0::numeric)
#  entries_check        | (debit_account_id <> credit_account_id)
# Foreign key constraints:
#  entries_credit_account_id_fkey | (credit_account_id) REFERENCES accounts(id)
#  entries_debit_account_id_fkey  | (debit_account_id) REFERENCES accounts(id)
#  entries_entity_id_fkey         | (entity_id) REFERENCES entities(id)
#  entries_user_id_fkey           | (user_id) REFERENCES users(id)
# Triggers:
#  check_entity_and_accounts   | BEFORE INSERT ON entries FOR EACH ROW EXECUTE PROCEDURE check_entity_and_accounts()
#  no_updating_entries_user_id | BEFORE UPDATE ON entries FOR EACH ROW EXECUTE PROCEDURE no_updating_user_id()
#  update_account_balance      | BEFORE INSERT OR DELETE OR UPDATE ON entries FOR EACH ROW EXECUTE PROCEDURE update_account_balance()
