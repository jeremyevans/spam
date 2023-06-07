# frozen_string_literal: true
require 'capybara'
require 'capybara/dsl'
require 'capybara/optionally_validate_html5'
require 'rack/test'
require 'rack/mock'
ENV['RACK_ENV'] = 'test'

TRANSACTIONAL_TESTS = true
RESET_DRIVER = true
Gem.suffix_pattern

require_relative 'spam'
Tilt.finalize!

require_relative 'spec_helper'

db_name = Spam::DB.get{current_database.function}
raise "Doesn't look like a test database (#{db_name}), not running tests" unless db_name =~ /test\z/

begin
  require 'refrigerator'
rescue LoadError
else
  Refrigerator.freeze_core(:except=>['BasicObject'])
end

[:entries, :entities, :accounts, :account_types, :subusers, :users].each{|x| Spam::DB[x].delete}
Spam::DB[:users].insert(:password_hash=>BCrypt::Password.create("pass"), :name=>"default", :num_register_entries=>35, :id=>1)
Spam::DB[:users].insert(:password_hash=>BCrypt::Password.create("pass2"), :name=>"test", :num_register_entries=>35, :id=>2)
Spam::DB[:account_types].insert(:name=>"Asset", :id=>1)
Spam::DB[:account_types].insert(:name=>"Liability", :id=>2)
Spam::DB[:account_types].insert(:name=>"Income", :id=>3)
Spam::DB[:account_types].insert(:name=>"Expense", :id=>4)
Spam::DB[:accounts].insert(:user_id=>2, :balance=>0, :account_type_id=>1, :name=>"Test", :hidden=>false, :description=>"", :id=>5)
Spam::DB[:accounts].insert(:user_id=>2, :balance=>0, :account_type_id=>2, :name=>"Test Liability", :hidden=>false, :description=>"", :id=>6)
Spam::DB[:accounts].insert(:user_id=>1, :balance=>0, :account_type_id=>2, :name=>"Credit Card", :hidden=>false, :description=>"", :id=>2)
Spam::DB[:accounts].insert(:user_id=>1, :balance=>0, :account_type_id=>1, :name=>"Checking", :hidden=>false, :description=>"", :id=>1)
Spam::DB[:accounts].insert(:user_id=>1, :balance=>0, :account_type_id=>4, :name=>"Food", :hidden=>false, :description=>"", :id=>4)
Spam::DB[:accounts].insert(:user_id=>1, :balance=>0, :account_type_id=>3, :name=>"Salary", :hidden=>false, :description=>"", :id=>3)
Spam::DB[:entities].insert(:user_id=>1, :name=>"Restaurant", :id=>2)
Spam::DB[:entities].insert(:user_id=>1, :name=>"Employer", :id=>1)
Spam::DB[:entities].insert(:user_id=>1, :name=>"Card", :id=>3)
Spam::DB[:entities].insert(:user_id=>2, :name=>"Test", :id=>4)
Spam::DB[:entries].insert(:credit_account_id=>6, :reference=>"", :user_id=>2, :entity_id=>4, :cleared=>false, :amount=>100, :memo=>"", :date=>'2008-06-11', :debit_account_id=>5, :id=>1)
entries = Spam::DB[:entries].filter(:user_id => 1)
Spam::DB.reset_primary_key_sequence(:users)
Spam::DB.reset_primary_key_sequence(:accounts)
Spam::DB.reset_primary_key_sequence(:entities)

Spam::App.not_found{raise "path not found: #{request.path_info}"}

Capybara.exact = true
Capybara.app = Spam::App.freeze.app

class Minitest::Spec
  include Rack::Test::Methods
  include Capybara::DSL

  def remove_id(hash)
    h = hash.dup
    h.delete(:id)
    h
  end

  def login
    visit('/')
    fill_in 'Username', :with=>'default'
    fill_in 'Password', :with=>'pass'
    click_on 'Login'
  end

  def click_nav(link)
    allow_invisible{click_link link}
  end

  def allow_invisible
    Capybara.ignore_hidden_elements = false
    yield
  ensure
    Capybara.ignore_hidden_elements = true
  end
end

describe "SPAM" do
  it "should have working login" do 
    visit('/')
    page.title.must_equal "SPAM - Login"
    fill_in 'Username', :with=>'default'
    fill_in 'Password', :with=>'foo'
    click_on 'Login'
    page.html.must_include 'invalid password'

    fill_in 'Username', :with=>'default'
    fill_in 'Password', :with=>'pass'
    click_on 'Login'
    page.html.must_include 'You have been logged in'
  end

  it "should have working change password" do 
    login

    click_nav 'Change Password'
    fill_in 'Password', :with=>'pass'
    fill_in 'New Password', :with=>'pass3foo'
    fill_in 'Confirm Password', :with=>'pass2foo'
    click_button 'Change Password'
    page.html.must_include 'passwords do not match'
    BCrypt::Password.new(Spam::User[1].password_hash).must_be :==, 'pass'

    fill_in 'Password', :with=>'pass'
    click_button 'Change Password'
    page.html.must_include 'invalid password, does not meet requirements (minimum 6 characters)'
    BCrypt::Password.new(Spam::User[1].password_hash).must_be :==, 'pass'

    fill_in 'Password', :with=>'pass'
    fill_in 'New Password', :with=>'pass3foo'
    fill_in 'Confirm Password', :with=>'pass3foo'
    click_button 'Change Password'
    page.html.must_include 'Your password has been changed'
    BCrypt::Password.new(Spam::User[1].password_hash).must_be :==, 'pass3foo'
  end

  it "should be able to create and switch to sub-users" do 
    login

    page.html.wont_include "Switch User"
    page.html.wont_include "Return to Main User"

    click_nav 'Create User'
    click_button 'Create User'
    page.html.must_include 'User not created'
    Spam::DB[:subusers].where(:user_id=>1).get(:sub_user_id).must_be_nil

    fill_in 'Name', :with=>'Foo1'
    click_button 'Create User'
    page.html.must_include 'User created: Foo1'
    Spam::User[Spam::DB[:subusers].where(:user_id=>1).get(:sub_user_id)].password_hash.must_equal '*'

    click_nav 'Create User'
    fill_in 'Name', :with=>'Bar2'
    click_button 'Create User'
    page.html.must_include 'User created: Bar2'
    Spam::User[Spam::DB[:subusers].where(:user_id=>1).reverse(:sub_user_id).get(:sub_user_id)].password_hash.must_equal '*'

    page.title.must_equal "SPAM"
    page.html.must_include "Switch User"
    page.html.wont_include "Return to Main User"
    page.html.must_include "Credit Card"
    select "Foo1"
    click_button 'Switch to User'

    page.title.must_equal "SPAM:Foo1"
    page.html.wont_include "Switch User"
    page.html.must_include "Return to Main User"
    page.html.wont_include "Credit Card"
    page.html.wont_include "Create User"

    click_nav 'Manage Accounts'
    page.all('td').must_be_empty
    click_link 'New'
    fill_in 'Name*', :with=>'CC Foo'
    select 'Liability'
    select 'False'
    click_button 'Create'
    page.html.must_include "CC Foo"
    allow_invisible{find('#nav-register').click_link 'CC Foo'}
    page.all('td').length.must_equal 9

    click_link 'SPAM:Foo1'
    click_button 'Return to Main User'
    page.html.must_include "Credit Card"
    page.html.wont_include "CC Foo"

    select "Bar2"
    click_button 'Switch to User'
    page.html.wont_include "Credit Card"
    page.html.wont_include "CC Foo"

    allow_invisible{click_link 'Manage Accounts'}
    page.all('td').must_be_empty
    click_link 'New'
    fill_in 'Name*', :with=>'CC Bar'
    select 'Liability'
    select 'False'
    click_button 'Create'
    page.html.must_include "CC Bar"
    allow_invisible{find('#nav-register').click_link 'CC Bar'}
    page.all('td').length.must_equal 9
  end

  it "should have a working register form" do 
    login

    visit('/update/register/1')
    page.title.must_equal "SPAM - Checking Register"
    find('h2').text.must_equal 'Showing 35 Most Recent Entries'
    form = find('div#content form')
    form.all('tr').length.must_equal 2
    form.all("table thead tr th").map(&:text).must_equal 'Date/Num/Entity/Other Account/Memo/C/Amount/Balance/Modify'.split('/')
    form.all("option").map(&:text).must_equal '/Checking/Credit Card/Food/Salary'.split('/')

    fill_in "entry[date]", :with=>'2008-06-06'
    fill_in "entry[reference]", :with=>'DEP'
    fill_in "entity[name]", :with=>'Employer'
    select 'Salary'
    fill_in "entry[memo]", :with=>'Check'
    fill_in "entry[amount]", :with=>'1000'
    click_button 'Add'

    entry = entries.first
    remove_id(entry).must_equal(:date=>Date.new(2008,6,6), :reference=>'DEP', :entity_id=>1, :credit_account_id=>3, :debit_account_id=>1, :memo=>'Check', :amount=>BigDecimal('1000'), :cleared=>false, :user_id=>1)

    page.all("div#content form table tbody tr").last.all('td').map(&:text).must_equal '2008-06-06/DEP/Employer/Salary/Check//$1000.00/$1000.00/Modify'.split('/')
    click_on 'Modify'
    fill_in "entry[date]", :with=>'2008-06-07'
    fill_in "entry[reference]", :with=>'1000'
    fill_in "entity[name]", :with=>'Card'
    select 'Credit Card'
    fill_in "entry[memo]", :with=>'Payment'
    fill_in "entry[amount]", :with=>'-1000'
    check 'entry[cleared]'
    click_on 'Update'

    entries[:id => entry[:id]].must_equal(:date=>Date.new(2008,6,7), :reference=>'1000', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment', :amount=>BigDecimal('1000'), :cleared=>true, :user_id=>1, :id=>entry[:id])
    page.all("div#content form table tbody tr").last.all('td').map(&:text).must_equal '2008-06-07/1000/Card/Credit Card/Payment/R/$-1000.00/$-1000.00/Modify'.split('/')
    
    click_on 'Modify'
    click_on 'Add'

    fill_in "entry[date]", :with=>'2008-06-08'
    fill_in "entry[reference]", :with=>'1001'
    fill_in "entity[name]", :with=>'Card'
    select 'Credit Card'
    fill_in "entry[memo]", :with=>'Payment'
    fill_in "entry[amount]", :with=>'-1001'
    click_on 'Add'
    remove_id(entries.order(:id).last).must_equal(:date=>Date.new(2008,6,8), :reference=>'1001', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment', :amount=>BigDecimal('1001'), :cleared=>false, :user_id=>1)
  end

  describe 'with existing entry' do
    before do
      login
      @entry_id = entries.insert(:date=>Date.new(2008,06,07), :reference=>'1000', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment', :amount=>BigDecimal('1000'), :cleared=>false, :user_id=>1)
    end

    it "should have working reconcile page" do
      visit('/update/reconcile/1')
      form = find('div#content form')
      form.first('table').all('tr td').map{|x| x.text.strip}.must_equal "Previous Reconciled Balance/$0.00/Reconciling Changes/$0.00/New Reconciled Balance/$0.00/Expected Reconciled Balance//Off By/$0.00// ".split('/')[0...-1]
      form.all('caption').map(&:text).must_equal ['Credit Entries']
      form.all('table').last.all('thead th').map(&:text).must_equal %w'C Date Num Entity Amount'
      form.all('table').last.all('tbody td').map(&:text).must_equal '/2008-06-07/1000/Card/$1000.00'.split('/')

      check "entries[#{@entry_id}]"
      fill_in 'reconcile_to', :with=>'-1000.00'
      click_on 'Auto-Reconcile'
      page.find("input#credit_#{@entry_id}")[:checked].must_equal true

      click_on 'Clear Entries'
      entries.first[:cleared].must_equal true
      page.body.wont_include("credit_#{@entry_id}")
      page.first('table').all('tr td').map{|x| x.text.strip}.must_equal "Previous Reconciled Balance/$-1000.00/Reconciling Changes/$0.00/New Reconciled Balance/$-1000.00/Expected Reconciled Balance//Off By/$0.00// ".split('/')[0...-1]
    end

    it "should have correct reports" do
      visit('/reports/balance_sheet')
      page.all('th').map(&:text).must_equal 'Asset Accounts/Balance/Liability Accounts/Balance'.split('/')
      page.all('td').map(&:text).must_equal 'Checking/$-1000.00/Credit Card/$1000.00'.split('/')

      Spam::DB[:entries].insert(:date=>Date.new(2008,04,07), :reference=>'1001', :entity_id=>2, :credit_account_id=>3, :debit_account_id=>4, :memo=>'Food', :amount=>100, :cleared=>false, :user_id=>1)

      visit('/reports/earning_spending')
      page.all('th').map(&:text).must_equal 'Account/June 2008/May 2008/April 2008/March 2008/February 2008/January 2008/December 2007/November 2007/October 2007/September 2007/August 2007/July 2007'.split('/')
      page.all('td').map(&:text).must_equal 'Food///$-100.00//////////Salary///$100.00////////// '.split('/')[0...-1]

      visit('/reports/yearly_earning_spending')
      page.all('th').map(&:text).must_equal 'Account/2008'.split('/')
      page.all('td').map(&:text).must_equal 'Food/$-100.00/Salary/$100.00'.split('/')

      visit('/reports/income_expense')
      page.all('th').map(&:text).must_equal 'Month|Income|Expense|Profit/Loss'.split('|')
      page.all('td').map(&:text).must_equal '2008-06|$0.00|$0.00|$0.00|2008-04|$100.00|$100.00|$0.00'.split('|')

      visit('/reports/net_worth')
      page.all('th').map(&:text).must_equal 'Month/Assets/Liabilities/Net Worth/'.split('/')
      page.all('td').map(&:text).must_equal 'Current/$-1000.00/$-1000.00/$0.00/Start of 2008-06/$0.00/$0.00/$0.00/Start of 2008-04/$0.00/$0.00/$0.00'.split('/')

      Spam::DB[:entries].exclude(:id => @entry_id).update(:credit_account_id=>1)

      visit('/reports/earning_spending_by_entity')
      page.all('th').map(&:text).must_equal 'Account/June 2008/May 2008/April 2008/March 2008/February 2008/January 2008/December 2007/November 2007/October 2007/September 2007/August 2007/July 2007'.split('/')
      page.all('td').map(&:text).must_equal 'Restaurant///$-100.00////////// '.split('/')[0...-1]

      visit('/reports/yearly_earning_spending_by_entity')
      page.all('th').map(&:text).must_equal 'Account/2008'.split('/')
      page.all('td').map(&:text).must_equal 'Restaurant/$-100.00'.split('/')

      Spam::DB[:entries].insert(:date=>Date.new(2008,05,07), :reference=>'1002', :entity_id=>1, :credit_account_id=>3, :debit_account_id=>1, :amount=>200, :cleared=>false, :user_id=>1)

      visit('/reports/income_expense')
      page.all('th').map(&:text).must_equal 'Month|Income|Expense|Profit/Loss'.split('|')
      page.all('td').map(&:text).must_equal '2008-06|$0.00|$0.00|$0.00|2008-05|$200.00|$0.00|$200.00|2008-04|$0.00|$100.00|$-100.00'.split('|')

      click_link '2008-05'
      page.all('th').map(&:text).must_equal 'Date|Entity|Debit Account|Credit Account|Amount'.split('|')
      page.all('td').map(&:text).must_equal '2008-05-07|Employer|Checking|Salary|$200.00'.split('|')
    end
  end
end
