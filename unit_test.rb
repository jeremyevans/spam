ENV['RACK_ENV'] = 'test'
require_relative 'models'
include Spam
db_name = DB.get{current_database.function}
raise "Doesn't look like a test database (#{db_name}), not running tests" unless db_name =~ /test\z/

[:entries, :entities, :accounts, :account_types, :users].each{|x| DB[x].delete}
DB[:users].insert(:password_hash=>BCrypt::Password.create("blah"), :name=>"default", :num_register_entries=>35, :id=>1)
DB[:users].insert(:password_hash=>BCrypt::Password.create("blah2"), :name=>"test", :num_register_entries=>35, :id=>2)
DB[:account_types].insert(:name=>"Asset", :id=>1)
DB[:account_types].insert(:name=>"Liability", :id=>2)
DB[:account_types].insert(:name=>"Income", :id=>3)
DB[:account_types].insert(:name=>"Expense", :id=>4)

require_relative 'spec_helper'

describe Account do
  before(:all) do
    @account = Account.create(:name=>'TestAccount', :user_id=>2, :account_type_id=>1, :hidden=>false)
    @account2 = Account.create(:name=>'BestAccount', :user_id=>2, :account_type_id=>2)
    @entity = Entity.create(:name=>"blah", :user_id=>2)
    @entry = Entry.create(:date=>'2007-11-22', :user_id=>2, :debit_account=>@account, :credit_account=>@account2, :amount=>100, :entity=>@entity)
    @entry2 = Entry.create(:date=>'2008-11-22', :user_id=>2, :debit_account=>@account2, :credit_account=>@account, :amount=>50, :entity=>@entity)
    @account.refresh
    @account2.refresh
  end
  before do
    @account = Account.call(@account.values.dup)
    @account2 = Account.call(@account2.values.dup)
    @entity = Entity.call(@entity.values.dup)
    @entry = Entry.call(@entry.values.dup)
    @entry2 = Entry.call(@entry2.values.dup)
  end

  it "associations should be correct" do
    @account.account_type.name.must_equal 'Asset'
    @account.credit_entries.must_equal [@entry2]
    @account.debit_entries.must_equal [@entry]
    @account.recent_credit_entries.must_equal [@entry2]
    @account.recent_debit_entries.must_equal [@entry]
  end

  it ".for_select should be an array of arrays of names and ids" do
    Account.for_select.sort.must_equal [['BestAccount', @account2.id], ['TestAccount', @account.id]]
    Account.filter(:user_id=>1).for_select.must_equal []
  end

  it ".register_accounts should be a dataset giving Asset and Liability accounts" do
    Account.register_accounts.all.sort_by(&:name).must_equal [@account2, @account]
    Account.filter(:user_id=>1).register_accounts.all.must_equal []
    @account.update(:account_type_id=>3)
    Account.register_accounts.all.must_equal [@account2]
  end

  it ".unhidden should be a dataset giving unhidden accounts" do
    Account.unhidden.all.sort_by(&:name).must_equal [@account2, @account]
    Account.filter(:user_id=>1).unhidden.all.must_equal []
    @account.update(:hidden=>true)
    Account.unhidden.all.must_equal [@account2]
  end

  it ".user should be a dataset with for only a particular users accounts, ordered by name" do
    Account.user(1).all.must_equal []
    Account.user(2).all.must_equal [@account2, @account]
  end

  it "#cents should multiply the number given by 100 and return an integer" do
    @account.cents(100.50).must_equal 10050
  end

  it "#entries should return all entries for this account" do
    @account.entries.length.must_equal 2
    @account.entries.first.amount.must_equal(-50)
    @account.entries.last.amount.must_equal 100
    DB[:entries].delete
    @account.entries(:reload=>true).must_equal []
  end

  it "#entries_reconciling_to should return all unreconciled entries reconciling to a given amount" do
    @account.entries_reconciling_to(100).collect(&:id).must_equal [@entry.id]
    @account.entries_reconciling_to(-50).collect(&:id).must_equal [@entry2.id]
    @account.entries_reconciling_to(50).sort_by(&:amount).collect(&:id).must_equal [@entry2.id, @entry.id]
  end

  it "#entries_reconciling_to should return nil if no entries reconcile" do
    @account.entries_reconciling_to(75).must_be_nil
  end

  it "#entries_reconciling_to should take a definite entries argument" do
    @account.entries_reconciling_to(100, [@entry.id]).collect(&:id).must_equal [@entry.id]
    @account.entries_reconciling_to(-50, [@entry.id]).must_be_nil
    @account.entries_reconciling_to(50, [@entry2.id]).sort_by(&:amount).collect(&:id).must_equal [@entry2.id, @entry.id]
  end

  it "#entries_to_reconcile should be an array of cleared entries" do
    @account.entries_to_reconcile.length.must_equal 2
    @account.entries_to_reconcile.first.amount.must_equal(-50)
    @account.entries_to_reconcile.last.amount.must_equal 100
    @entry.update(:cleared=>true)
    @account.entries_to_reconcile.length.must_equal 1
    @account.entries_to_reconcile.first.amount.must_equal(-50)
  end

  it "#entries_to_reconcile should restrict the entries to either debit or credit entries if given an argument" do
    @account.entries_to_reconcile(:debit).length.must_equal 1
    @account.entries_to_reconcile(:debit).first.amount.must_equal 100
    @entry.update(:cleared=>true)
    @account.entries_to_reconcile(:debit).must_equal []
  end

  it "#last_entry_for_entity should give the last entry for the given entity name related to this account, if any" do
    @account.last_entry_for_entity("blah").must_equal @entry2
    @entry2.update(:entity=>nil)
    @account.last_entry_for_entity("blah").must_equal @entry
    @entry.update(:entity=>nil)
    @account.last_entry_for_entity("blah").must_be_nil
  end

  it "#last_entry_for_entity should return nil for a non matching entity name" do
    @account.last_entry_for_entity("lah").must_be_nil
  end

  it "#money_balance should be a string giving the balance as a dollar figure" do
    @account.money_balance.must_equal '$50.00'
    @account2.money_balance.must_equal '$-50.00'
  end

  it "#next_check_number should give the next check number to use" do
    @entry.update(:reference=>'1034')
    @account.next_check_number.must_equal '1035'
  end

  it "#short_name should be the first 31 letters of name" do
    @account.set(:name=>'A' * 50)
    @account.short_name.must_equal 'A' * 31
  end

  it "#unreconciled_balance should be the current balance less the sum of entries not cleared" do
    @account.unreconciled_balance.must_equal 0
    @entry.update(:cleared=>true)
    @account.unreconciled_balance.must_equal 100
    @entry2.update(:cleared=>true)
    @account.unreconciled_balance.must_equal 50
    @entry.update(:cleared=>false)
    @account.unreconciled_balance.must_equal(-50)
  end
end

describe Entity do
  before(:all) do
    @entity = Entity.create(:name=>"blah", :user_id=>2)
  end
  before do
    @entity = Entity.call(@entity.values.dup)
  end

  it "associations should be correct" do
    @entity.entries.must_equal []
    @entity.recent_entries.must_equal []
  end

  it ".user should be a dataset with for only a particular users accounts, ordered by name" do
    Entity.user(1).all.must_equal []
    Entity.user(2).all.must_equal [@entity]
    @entity2 = Entity.create(:name=>'a', :user_id=>2)
    Entity.user(2).all.must_equal [@entity2, @entity]
  end

  it "#short_name should be the first 31 letters of name" do
    @entity.set(:name=>'A' * 50)
    @entity.short_name.must_equal 'A' * 31
  end
end

describe Entry do
  before(:all) do
    @account = Account.create(:name=>'TestAccount', :user_id=>2, :account_type_id=>1, :hidden=>false)
    @account2 = Account.create(:name=>'BestAccount', :user_id=>2, :account_type_id=>2)
    @entity = Entity.create(:name=>"blah", :user_id=>2)
    @entry = Entry.create(:date=>'2007-11-22', :user_id=>2, :debit_account=>@account, :credit_account=>@account2, :amount=>100, :entity=>@entity)
    @entry2 = Entry.create(:date=>'2008-11-22', :user_id=>2, :debit_account=>@account2, :credit_account=>@account, :amount=>50, :entity=>@entity)
    @account.refresh
    @account2.refresh
  end
  before do
    @account = Account.call(@account.values.dup)
    @account2 = Account.call(@account2.values.dup)
    @entity = Entity.call(@entity.values.dup)
    @entry = Entry.call(@entry.values.dup)
    @entry2 = Entry.call(@entry2.values.dup)
  end

  it "associations should be correct" do
    @entry.refresh
    @entry.credit_account.must_equal @account2
    @entry.debit_account.must_equal @account
    @entry.entity.must_equal @entity
  end

  it ".user should be a dataset with for only a particular users accounts, ordered by name" do
    Entry.user(1).all.must_equal []
    Entry.user(2).all.sort_by(&:amount).must_equal [@entry2, @entry]
  end

  it ".with_account should be a dataset method that only gives entries with the given account_id" do
    Entry.with_account(@account.id).all.sort_by(&:amount).must_equal [@entry2, @entry]
    Entry.dataset.with_account(@account2.id).all.sort_by(&:amount).must_equal [@entry2, @entry]
    account3 = Account.create(:name=>'RestAccount', :user_id=>2, :account_type_id=>3)
    @entry.update(:debit_account=>account3)
    Entry.with_account(@account.id).all.sort_by(&:amount).must_equal [@entry2]
    Entry.with_account(@account2.id).all.sort_by(&:amount).must_equal [@entry2, @entry]
    Entry.with_account(account3.id).all.sort_by(&:amount).must_equal [@entry]
    @entry2.update(:credit_account=>account3)
    Entry.with_account(@account.id).all.sort_by(&:amount).must_equal []
    Entry.with_account(@account2.id).all.sort_by(&:amount).must_equal [@entry2, @entry]
    Entry.with_account(account3.id).all.sort_by(&:amount).must_equal [@entry2, @entry]
    @entry.update(:credit_account=>@account)
    Entry.with_account(@account.id).all.sort_by(&:amount).must_equal [@entry]
    Entry.with_account(@account2.id).all.sort_by(&:amount).must_equal [@entry2]
    Entry.with_account(account3.id).all.sort_by(&:amount).must_equal [@entry2, @entry]

    Entry.with_account(@account.id).with_account(@account2.id).all.sort_by(&:amount).must_equal []
    Entry.with_account(@account.id).with_account(account3.id).all.sort_by(&:amount).must_equal [@entry]
    Entry.with_account(@account2.id).with_account(account3.id).all.sort_by(&:amount).must_equal [@entry2]
  end

  it "#scaffold_name should include the date, reference, enty, debit account, credit account, and amount" do
    @entry.scaffold_name.must_equal '2007-11-22--blah-TestAccount-BestAccount-$100.00'
    @entry2.scaffold_name.must_equal '2008-11-22--blah-BestAccount-TestAccount-$50.00'
    @entry.reference = '1023'
    @entry.scaffold_name.must_equal '2007-11-22-1023-blah-TestAccount-BestAccount-$100.00'
  end

  it "#money_amount should be a string giving the amount as a dollar figure" do
    @entry.money_amount.must_equal '$100.00'
    @entry2.money_amount.must_equal '$50.00'
  end

  it "#main_account= should reverse the amount if the account is the credit account, and set the other_account attribute" do
    @entry.main_account = @account
    @entry.amount.must_equal 100
    @entry.other_account.must_equal @account2
    @entry2.main_account = @account
    @entry2.amount.must_equal(-50)
    @entry2.other_account.must_equal @account2
  end
end

describe User do
  it "#password= should set a new password hash" do
    user = User[2]
    pw = user.password_hash
    user.password = 'foo'
    user.password_hash.wont_equal pw
  end
end
