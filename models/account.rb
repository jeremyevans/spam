class Account < Sequel::Model
  many_to_one :account_type
  one_to_many :entries, :read_only=>true, :order=>[:date, :reference, :amount].map{|s| Sequel.desc(s)}, :dataset=>proc{|r| r.associated_dataset.with_account(id)}, :eager=>[:entity, :credit_account, :debit_account], :after_load=>:set_main_account, :reciprocal=>nil
  one_to_many :credit_entries, :class_name=>'Entry', :key=>:credit_account_id, :eager=>[:debit_account, :entity], :order=>Sequel.desc(:date)
  one_to_many :debit_entries, :class_name=>'Entry', :key=>:debit_account_id, :eager=>[:credit_account, :entity], :order=>Sequel.desc(:date)
  one_to_many :recent_credit_entries, :class_name=>'Entry', :key=>:credit_account_id, :eager=>[:debit_account, :entity], :order=>Sequel.desc(:date), :limit=>25
  one_to_many :recent_debit_entries, :class_name=>'Entry', :key=>:debit_account_id, :eager=>[:credit_account, :entity], :order=>Sequel.desc(:date), :limit=>25
  
  dataset_module do
    def for_select
      all.collect{|account|[account.short_name, account.id]}
    end
  end
  
  subset(:register_accounts, :account_type_id=>[1,2])
  subset(:unhidden, Sequel.~(:hidden))

  def self.user(user_id)
    filter(:user_id=>user_id).order(:name)
  end

  def cents(dollars)
    (dollars * 100).round.to_i
  end
  
  def entries_reconciling_to(reconciled_balance, definite_entries = [], max_seconds = nil)
    entries = entries_to_reconcile
    definite_entries, entries = entries.partition{|entry| definite_entries.include?(entry.id)}
    definite_sum = definite_entries.inject(0){|x, y| x + y.amount}
    int_value_dict = {}
    entries.each{|entry| (int_value_dict[cents(entry.amount)] ||= []) << entry}
    int_values = entries.collect{|entry| cents(entry.amount)}
    if subset = SubsetSum.subset_sum(int_values, cents(reconciled_balance) - cents(unreconciled_balance) - cents(definite_sum), max_seconds)
      return subset.collect{|value| int_value_dict[value].shift} + (definite_entries || [])
    end
  end

  def entries_to_reconcile(type=nil)
    if type
      Entry.eager(:entity).filter(:"#{type}_account_id"=>id).exclude(:cleared).order(:date, :reference, Sequel.desc(:amount)).all
    else
      entries_dataset.exclude(:cleared).all{|x| x.main_account = self}
    end
  end

  def last_entry_for_entity(entity_name)
    return unless entity = Entity[:name=>entity_name, :user_id=>user_id]
    entity.entries_dataset.with_account(id).reverse_order(:date, :reference, :amount).first
  end

  def money_balance
    balance.to_money
  end

  def next_check_number
    return '' if account_type_id != 1
    return '' unless entry = Entry.with_account(id).filter(Sequel.like(:reference, /^\d+$/)).reverse_order(:id).first
    return '' unless entry.reference.to_i > 0
    (entry.reference.to_i+1).to_s
  end

  def short_name
    name[0..30]
  end

  def unreconciled_balance
    balance - (Entry.with_account(id).exclude(:cleared).get{|o| o.sum(Sequel.case({{:credit_account_id => id}=>Sequel.*(:amount, -1)}, :amount))} || 0)
  end

  private

  def set_main_account(entries)
    entries.each{|e| e.main_account = self}
  end
end

# Table: accounts
# Columns:
#  id              | integer       | PRIMARY KEY DEFAULT nextval('accounts_id_seq'::regclass)
#  name            | text          | NOT NULL
#  balance         | numeric(10,2) | NOT NULL DEFAULT 0
#  description     | text          |
#  hidden          | boolean       | DEFAULT false
#  account_type_id | integer       | NOT NULL
#  user_id         | integer       | NOT NULL
# Indexes:
#  accounts_pkey  | PRIMARY KEY btree (id)
#  accounts_namei | UNIQUE btree (user_id, lower(name))
# Foreign key constraints:
#  accounts_account_type_id_fkey | (account_type_id) REFERENCES account_types(id)
#  accounts_user_id_fkey         | (user_id) REFERENCES users(id)
# Referenced By:
#  entries | entries_credit_account_id_fkey | (credit_account_id) REFERENCES accounts(id)
#  entries | entries_debit_account_id_fkey  | (debit_account_id) REFERENCES accounts(id)
# Triggers:
#  no_updating_accounts_user_id | BEFORE UPDATE ON accounts FOR EACH ROW EXECUTE PROCEDURE no_updating_user_id()
