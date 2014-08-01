require 'rubygems'
require 'capybara'
require 'capybara/dsl'
require 'capybara/rspec/matchers'
require 'rack/test'
ENV['RACK_ENV'] = 'test'

require ::File.expand_path('../spam',  __FILE__)

db_name = DB.get{current_database{}}
raise "Doesn't look like a test database (#{db_name}), not running tests" unless db_name =~ /test\z/

[:entries, :entities, :accounts, :account_types, :users].each{|x| DB[x].delete}
DB[:users] << {:password_hash=>BCrypt::Password.create("pass"), :name=>"default", :num_register_entries=>35, :id=>1}
DB[:users] << {:password_hash=>BCrypt::Password.create("pass2"), :name=>"test", :num_register_entries=>35, :id=>2}
DB[:account_types] << {:name=>"Asset", :id=>1}
DB[:account_types] << {:name=>"Liability", :id=>2}
DB[:account_types] << {:name=>"Income", :id=>3}
DB[:account_types] << {:name=>"Expense", :id=>4}
DB[:accounts] << {:user_id=>2, :balance=>0, :account_type_id=>1, :name=>"Test", :hidden=>false, :description=>"", :id=>5}
DB[:accounts] << {:user_id=>2, :balance=>0, :account_type_id=>2, :name=>"Test Liability", :hidden=>false, :description=>"", :id=>6}
DB[:accounts] << {:user_id=>1, :balance=>0, :account_type_id=>2, :name=>"Credit Card", :hidden=>false, :description=>"", :id=>2}
DB[:accounts] << {:user_id=>1, :balance=>0, :account_type_id=>1, :name=>"Checking", :hidden=>false, :description=>"", :id=>1}
DB[:accounts] << {:user_id=>1, :balance=>0, :account_type_id=>4, :name=>"Food", :hidden=>false, :description=>"", :id=>4}
DB[:accounts] << {:user_id=>1, :balance=>0, :account_type_id=>3, :name=>"Salary", :hidden=>false, :description=>"", :id=>3}
DB[:entities] << {:user_id=>1, :name=>"Restaurant", :id=>2}
DB[:entities] << {:user_id=>1, :name=>"Employer", :id=>1}
DB[:entities] << {:user_id=>1, :name=>"Card", :id=>3}
DB[:entities] << {:user_id=>2, :name=>"Test", :id=>4}
DB[:entries] << {:credit_account_id=>6, :reference=>"", :user_id=>2, :entity_id=>4, :cleared=>false, :amount=>100, :memo=>"", :date=>'2008-06-11', :debit_account_id=>5, :id=>1}
Entries = DB[:entries].filter(:user_id => 1)

Capybara.app = Spam.app

class Spec::Example::ExampleGroup
  include Rack::Test::Methods
  include Capybara::DSL
  include Capybara::RSpecMatchers

  after do
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end

  def execute(*args, &block)
    result = nil
    Sequel::Model.db.transaction(:rollback=>:always){result = super(*args, &block)}
    result
  end

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
end

describe "SPAM" do
  it "should have working login" do 
    visit('/')
    find('title').text.should == 'SPAM - Login'
    fill_in 'Username', :with=>'default'
    fill_in 'Password', :with=>'foo'
    click_on 'Login'
    page.html.should =~ /Incorrect username or password/

    fill_in 'Username', :with=>'default'
    fill_in 'Password', :with=>'pass'
    click_on 'Login'
    page.html.should =~ /You have been logged in/
  end

  it "should have working change password" do 
    login

    click_on 'Change Password'
    within('div#content form') do
      fill_in 'Password', :with=>'pass3foo'
      fill_in 'Confirm Password', :with=>'pass2foo'
      click_on 'Change Password'
    end
    BCrypt::Password.new(User[1].password_hash).should == 'pass'
    page.html.should =~ /Passwords don't match, please try again/

    within('div#content form') do
      click_on 'Change Password'
    end
    BCrypt::Password.new(User[1].password_hash).should == 'pass'
    page.html.should =~ /Password too short, use at least 6 characters, preferably 10 or more/

    within('div#content form') do
      fill_in 'Password', :with=>'pass3foo'
      fill_in 'Confirm Password', :with=>'pass3foo'
      click_on 'Change Password'
    end
    page.html.should =~ /Password updated/
    BCrypt::Password.new(User[1].password_hash).should == 'pass3foo'
  end

  it "should have a working register form" do 
    login

    visit('/update/register/1')
    find('title').text.should == 'SPAM - Checking Register'
    find('h3').text.should == 'Showing 35 Most Recent Entries'
    form = find('div#content form')
    form.all('tr').length.should == 2
    form.all("table thead tr th").map{|s| s.text}.should == 'Date/Num/Entity/Other Account/Memo/C/Amount/Balance/Modify'.split('/')
    form.all("option").map{|s| s.text}.should == '/Checking/Credit Card/Food/Salary'.split('/')

    fill_in "entry[date]", :with=>'2008-06-06'
    fill_in "entry[reference]", :with=>'DEP'
    fill_in "entity[name]", :with=>'Employer'
    select 'Salary'
    fill_in "entry[memo]", :with=>'Check'
    fill_in "entry[amount]", :with=>'1000'
    click_on 'Add'

    entry = Entries.first
    remove_id(entry).should == {:date=>Date.new(2008,6,6), :reference=>'DEP', :entity_id=>1, :credit_account_id=>3, :debit_account_id=>1, :memo=>'Check', :amount=>BigDecimal.new('1000'), :cleared=>false, :user_id=>1}

    page.all("div#content form table tbody tr").last.all('td').map{|s| s.text}.should == '2008-06-06/DEP/Employer/Salary/Check//$1000.00/$1000.00/Modify'.split('/')
    click_on 'Modify'
    fill_in "entry[date]", :with=>'2008-06-07'
    fill_in "entry[reference]", :with=>'1000'
    fill_in "entity[name]", :with=>'Card'
    select 'Credit Card'
    fill_in "entry[memo]", :with=>'Payment'
    fill_in "entry[amount]", :with=>'-1000'
    check 'entry[cleared]'
    click_on 'Update'

    Entries[:id => entry[:id]].should == {:date=>Date.new(2008,6,7), :reference=>'1000', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment', :amount=>BigDecimal.new('1000'), :cleared=>true, :user_id=>1, :id=>entry[:id]}
    page.all("div#content form table tbody tr").last.all('td').map{|s| s.text}.should == '2008-06-07/1000/Card/Credit Card/Payment/R/$-1000.00/$-1000.00/Modify'.split('/')
    
    click_on 'Modify'
    click_on 'Add'

    fill_in "entry[date]", :with=>'2008-06-08'
    fill_in "entry[reference]", :with=>'1001'
    fill_in "entity[name]", :with=>'Card'
    select 'Credit Card'
    fill_in "entry[memo]", :with=>'Payment'
    fill_in "entry[amount]", :with=>'-1001'
    click_on 'Add'
    remove_id(Entries.order(:id).last).should == {:date=>Date.new(2008,6,8), :reference=>'1001', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment', :amount=>BigDecimal.new('1001'), :cleared=>false, :user_id=>1}
  end

  describe 'with existing entry' do
    before do
      login
      @entry_id = Entries.insert(:date=>Date.new(2008,06,07), :reference=>'1000', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment', :amount=>BigDecimal.new('1000'), :cleared=>false, :user_id=>1)
    end

    it "should have working reconcile page" do
      visit('/update/reconcile/1')
      form = find('div#content form')
      form.find('table').all('tr td').map{|x| x.text.strip}.should == "Unreconciled Balance/$0.00/Reconciling Changes/$0.00/Reconciled Balance/$0.00/Off By/$0.00/Reconcile To/// ".split('/')[0...-1]
      form.all('caption').map{|s| s.text}.should == 'Debit Entries/Credit Entries'.split('/')
      form.all('table').last.all('thead th').map{|s| s.text}.should == %w'C Date Num Entity Amount'
      form.all('table').last.all('tbody td').map{|s| s.text}.should == '/2008-06-07/1000/Card/$1000.00'.split('/')

      check "entries[#{@entry_id}]"
      fill_in 'reconcile_to', :with=>'-1000.00'
      click_on 'Auto-Reconcile'
      page.find("input#credit_#{@entry_id}")[:checked].should be_true

      click_on 'Clear Entries'
      Entries.first[:cleared].should == true
      page.all("input#credit_#{@entry_id}").should == []
      page.find('table').all('td').map{|x| x.text.strip}.should == "Unreconciled Balance/$-1000.00/Reconciling Changes/$0.00/Reconciled Balance/$-1000.00/Off By/$-1000.00/Reconcile To/// ".split('/')[0...-1]
    end

    it "should have correct reports" do
      visit('/reports/balance_sheet')
      page.all('table th, table td').map{|x| x.text}.should == 'Asset Accounts/Balance/Checking/$-1000.00/Liability Accounts/Balance/Credit Card/$1000.00'.split('/')

      DB[:entries].insert(:date=>Date.new(2008,04,07), :reference=>'1001', :entity_id=>2, :credit_account_id=>3, :debit_account_id=>4, :memo=>'Food', :amount=>100, :cleared=>false, :user_id=>1)

      visit('/reports/earning_spending')
      page.all('th, td').map{|x| x.text}.should == 'Account/June 2008/May 2008/April 2008/March 2008/February 2008/January 2008/December 2007/November 2007/October 2007/September 2007/August 2007/July 2007/Food///$-100.00//////////Salary///$100.00////////// '.split('/')[0...-1]

      visit('/reports/yearly_earning_spending')
      page.all('th, td').map{|x| x.text}.should == 'Account/2008/Food/$-100.00/Salary/$100.00'.split('/')

      visit('/reports/income_expense')
      page.all('th, td').map{|x| x.text}.should == 'Month|Income|Expense|Profit/Loss|2008-06|$0.00|$0.00|$0.00|2008-04|$100.00|$100.00|$0.00'.split('|')

      visit('/reports/net_worth')
      page.all('th, td').map{|x| x.text}.should == 'Month/Assets/Liabilities/Net Worth/Current/$-1000.00/$-1000.00/$0.00/Start of 2008-06/$0.00/$0.00/$0.00/Start of 2008-04/$0.00/$0.00/$0.00'.split('/')

      DB[:entries].exclude(:id => @entry_id).update(:credit_account_id=>1)

      visit('/reports/earning_spending_by_entity')
      page.all('th, td').map{|x| x.text}.should == 'Account/June 2008/May 2008/April 2008/March 2008/February 2008/January 2008/December 2007/November 2007/October 2007/September 2007/August 2007/July 2007/Restaurant///$-100.00////////// '.split('/')[0...-1]

      visit('/reports/yearly_earning_spending_by_entity')
      page.all('th, td').map{|x| x.text}.should == 'Account/2008/Restaurant/$-100.00'.split('/')
    end
  end
end
