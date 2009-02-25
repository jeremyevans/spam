#!/usr/local/bin/spec
require 'rubygems'
$:.unshift('/data/code/sequel/lib')
require 'sequel'
DB = Sequel.postgres('spamtest', :user=>'guest', :host=>'/tmp')
require 'subset_sum'
require 'lib/to_money'
require 'digest/sha1'
Dir['app/models/*.rb'].each{|f| require(f)}
[:entries, :entities, :accounts, :account_types, :users].each{|x| DB[x].delete}
DB[:users] << {:password=>"be358e142bf770bbd5aeb563b868c3c13a833c14", :salt=>"daaaeef2b3502ebd0a65698cc994ee767589ca1c", :name=>"default", :num_register_entries=>35, :id=>1}
DB[:users] << {:password=>"                                        ", :salt=>"                                        ", :name=>"test", :num_register_entries=>35, :id=>2}
DB[:account_types] << {:name=>"Asset", :id=>1}
DB[:account_types] << {:name=>"Liability", :id=>2}
DB[:account_types] << {:name=>"Income", :id=>3}
DB[:account_types] << {:name=>"Expense", :id=>4}

describe Account do
  before do
    @account = Account.create(:name=>'TestAccount', :user_id=>2, :account_type_id=>1, :hidden=>false)
    @account2 = Account.create(:name=>'BestAccount', :user_id=>2, :account_type_id=>2)
    @entity = Entity.create(:name=>"blah", :user_id=>2)
    @entry = Entry.create(:date=>'2007-11-22', :user_id=>2, :debit_account=>@account, :credit_account=>@account2, :amount=>100, :entity=>@entity)
    @entry2 = Entry.create(:date=>'2008-11-22', :user_id=>2, :debit_account=>@account2, :credit_account=>@account, :amount=>50, :entity=>@entity)
    @account.refresh
    @account2.refresh
  end
  after do
    Entry.delete
    Entity.delete
    Account.delete
  end

  specify "associations should be correct" do
    @account.account_type.name.should == 'Asset'
    @account.credit_entries.should == [@entry2]
    @account.debit_entries.should == [@entry]
    @account.recent_credit_entries.should == [@entry2]
    @account.debit_entries.should == [@entry]
  end

  specify ".for_select should be an array of arrays of names and ids" do
    Account.for_select.should == [['BestAccount', @account2.id], ['TestAccount', @account.id]]
    Account.filter(:user_id=>1).for_select.should == []
  end

  specify ".register_accounts should be a dataset giving Asset and Liability accounts" do
    Account.register_accounts.all.sort_by{|a| a.name}.should == [@account2, @account]
    Account.filter(:user_id=>1).register_accounts.all.should == []
    @account.update(:account_type_id=>3)
    Account.register_accounts.all.should == [@account2]
  end

  specify ".unhidden should be a dataset giving unhidden accounts" do
    Account.unhidden.all.sort_by{|a| a.name}.should == [@account2, @account]
    Account.filter(:user_id=>1).unhidden.all.should == []
    @account.update(:hidden=>true)
    Account.unhidden.all.should == [@account2]
  end

  specify ".user should be a dataset with for only a particular users accounts, ordered by name" do
    Account.user(1).all.should == []
    Account.user(2).all.should == [@account2, @account]
  end

  specify "#cents should multiply the number given by 100 and return an integer" do
    @account.cents(100.50).should == 10050
  end

  specify "#entries should return all entries for this account" do
    @account.entries.length.should == 2
    @account.entries.first.amount.should == -50
    @account.entries.last.amount.should == 100
    Entry.delete
    @account.entries(true).should == []
  end

  specify "#entries_reconciling_to should return all unreconciled entries reconciling to a given amount" do
    @account.entries_reconciling_to(100).collect{|e| e.id}.should == [@entry.id]
    @account.entries_reconciling_to(-50).collect{|e| e.id}.should == [@entry2.id]
    @account.entries_reconciling_to(50).sort_by{|e| e.amount}.collect{|e| e.id}.should == [@entry2.id, @entry.id]
  end

  specify "#entries_reconciling_to should return nil if no entries reconcile" do
    @account.entries_reconciling_to(75).should == nil
  end

  specify "#entries_reconciling_to should take a definite entries argument" do
    @account.entries_reconciling_to(100, [@entry.id]).collect{|e| e.id}.should == [@entry.id]
    @account.entries_reconciling_to(-50, [@entry.id]).should == nil
    @account.entries_reconciling_to(50, [@entry2.id]).sort_by{|e| e.amount}.collect{|e| e.id}.should == [@entry2.id, @entry.id]
  end

  specify "#entries_to_reconcile should be an array of cleared entries" do
    @account.entries_to_reconcile.length.should == 2
    @account.entries_to_reconcile.first.amount.should == -50
    @account.entries_to_reconcile.last.amount.should == 100
    @entry.update(:cleared=>true)
    @account.entries_to_reconcile.length.should == 1
    @account.entries_to_reconcile.first.amount.should == -50
  end

  specify "#entries_to_reconcile should restrict the entries to either debit or credit entries if given an argument" do
    @account.entries_to_reconcile(:debit).length.should == 1
    @account.entries_to_reconcile(:debit).first.amount.should == 100
    @entry.update(:cleared=>true)
    @account.entries_to_reconcile(:debit).should == []
  end

  specify "#last_entry_for_entity should give the last entry for the given entity name related to this account, if any" do
    @account.last_entry_for_entity("blah").should == @entry2
    @entry2.update(:entity=>nil)
    @account.last_entry_for_entity("blah").should == @entry
    @entry.update(:entity=>nil)
    @account.last_entry_for_entity("blah").should == nil
  end

  specify "#last_entry_for_entity should return nil for a non matching entity name" do
    @account.last_entry_for_entity("lah").should == nil
  end

  specify "#money_balance should be a string giving the balance as a dollar figure" do
    @account.money_balance.should == '$50.00'
    @account2.money_balance.should == '$-50.00'
  end

  specify "#next_check_number should give the next check number to use" do
    @entry.update(:reference=>'1034')
    @account.next_check_number.should == '1035'
  end

  specify "#scaffold_name should be the first 31 letters of name" do
    @account.set(:name=>'A' * 50)
    @account.scaffold_name.should == 'A' * 31
  end

  specify "#unreconciled_balance should be the current balance less the sum of entries not cleared" do
    @account.unreconciled_balance.should == 0
    @entry.update(:cleared=>true)
    @account.unreconciled_balance.should == 100
    @entry2.update(:cleared=>true)
    @account.unreconciled_balance.should == 50
    @entry.update(:cleared=>false)
    @account.unreconciled_balance.should == -50
  end
end

describe Entity do
  before do
    @entity = Entity.create(:name=>"blah", :user_id=>2)
  end
  after do
    Entity.delete
  end

  specify "associations should be correct" do
    @entity.entries.should == []
    @entity.recent_entries.should == []
  end

  specify ".user should be a dataset with for only a particular users accounts, ordered by name" do
    Entity.user(1).all.should == []
    Entity.user(2).all.should == [@entity]
    @entity2 = Entity.create(:name=>'a', :user_id=>2)
    Entity.user(2).all.should == [@entity2, @entity]
  end

  specify "#scaffold_name should be the first 31 letters of name" do
    @entity.set(:name=>'A' * 50)
    @entity.scaffold_name.should == 'A' * 31
  end
end

describe Entry do
  before do
    @account = Account.create(:name=>'TestAccount', :user_id=>2, :account_type_id=>1, :hidden=>false)
    @account2 = Account.create(:name=>'BestAccount', :user_id=>2, :account_type_id=>2)
    @entity = Entity.create(:name=>"blah", :user_id=>2)
    @entry = Entry.create(:date=>'2007-11-22', :user_id=>2, :debit_account=>@account, :credit_account=>@account2, :amount=>100, :entity=>@entity)
    @entry2 = Entry.create(:date=>'2008-11-22', :user_id=>2, :debit_account=>@account2, :credit_account=>@account, :amount=>50, :entity=>@entity)
    @account.refresh
    @account2.refresh
  end
  after do
    Entry.delete
    Entity.delete
    Account.delete
  end

  specify "associations should be correct" do
    @entry.refresh
    @entry.credit_account.should == @account2
    @entry.debit_account.should == @account
    @entry.entity.should == @entity
  end

  specify ".user should be a dataset with for only a particular users accounts, ordered by name" do
    Entry.user(1).all.should == []
    Entry.user(2).all.sort_by{|x| x.amount}.should == [@entry2, @entry]
  end

  specify ".with_account should be a dataset method that only gives entries with the given account_id" do
    Entry.with_account(@account.id).all.sort_by{|x| x.amount}.should == [@entry2, @entry]
    Entry.dataset.with_account(@account2.id).all.sort_by{|x| x.amount}.should == [@entry2, @entry]
    account3 = Account.create(:name=>'RestAccount', :user_id=>2, :account_type_id=>3)
    @entry.update(:debit_account=>account3)
    Entry.with_account(@account.id).all.sort_by{|x| x.amount}.should == [@entry2]
    Entry.with_account(@account2.id).all.sort_by{|x| x.amount}.should == [@entry2, @entry]
    Entry.with_account(account3.id).all.sort_by{|x| x.amount}.should == [@entry]
    @entry2.update(:credit_account=>account3)
    Entry.with_account(@account.id).all.sort_by{|x| x.amount}.should == []
    Entry.with_account(@account2.id).all.sort_by{|x| x.amount}.should == [@entry2, @entry]
    Entry.with_account(account3.id).all.sort_by{|x| x.amount}.should == [@entry2, @entry]
    @entry.update(:credit_account=>@account)
    Entry.with_account(@account.id).all.sort_by{|x| x.amount}.should == [@entry]
    Entry.with_account(@account2.id).all.sort_by{|x| x.amount}.should == [@entry2]
    Entry.with_account(account3.id).all.sort_by{|x| x.amount}.should == [@entry2, @entry]

    Entry.with_account(@account.id).with_account(@account2.id).all.sort_by{|x| x.amount}.should == []
    Entry.with_account(@account.id).with_account(account3.id).all.sort_by{|x| x.amount}.should == [@entry]
    Entry.with_account(@account2.id).with_account(account3.id).all.sort_by{|x| x.amount}.should == [@entry2]
  end

  specify "#scaffold_name should include the date, reference, enty, debit account, credit account, and amount" do
    @entry.scaffold_name.should == '2007-11-22--blah-TestAccount-BestAccount-$100.00'
    @entry2.scaffold_name.should == '2008-11-22--blah-BestAccount-TestAccount-$50.00'
    @entry.reference = '1023'
    @entry.scaffold_name.should == '2007-11-22-1023-blah-TestAccount-BestAccount-$100.00'
  end

  specify "#money_amount should be a string giving the amount as a dollar figure" do
    @entry.money_amount.should == '$100.00'
    @entry2.money_amount.should == '$50.00'
  end

  specify "#main_account= should reverse the amount if the account is the credit account, and set the other_account attribute" do
    @entry.main_account = @account
    @entry.amount.should == 100
    @entry.other_account.should == @account2
    @entry2.main_account = @account
    @entry2.amount.should == -50
    @entry2.other_account.should == @account2
  end
end

describe User do
  specify "#password= should create a new salt" do
    user = User[2]
    salt = user.salt
    user.password = 'blah'
    user.salt.should_not == salt
    user.salt.should =~ /\A[0-9a-f]{40}\z/
  end

  specify "#password= should set the SHA1 password hash based on the salt and password" do
    user = User[2]
    user.password = 'blah'
    user.password.should == Digest::SHA1.new.update(user.salt).update('blah').hexdigest
  end

  specify ".login_user_id should return nil unless both username and password are present" do
    User.login_user_id(nil, nil).should == nil
    User.login_user_id('default', nil).should == nil
    User.login_user_id(nil, 'blah').should == nil
  end

  specify ".login_user_id should return nil unless a user with a given username exists" do
    User.login_user_id('blah', nil).should == nil
  end

  specify ".login_user_id should return nil unless the password matches for that username" do
    User.login_user_id('test', 'wrong').should == nil
  end

  specify ".login_user_id should return the user's id if the password matches " do
    user = User[2]
    user.password = 'blah'
    user.save
    User.login_user_id('test', 'blah').should == 2
  end
end
