require 'capybara'
require 'capybara-webkit'
require 'capybara/dsl'
require 'headless'

ENV['RACK_ENV'] = 'test'
require_relative 'models'

include Spam

db_name = DB.get{current_database.function}
raise "Doesn't look like a test database (#{db_name}), not running tests" unless db_name =~ /test\z/

[:entries, :entities, :accounts, :account_types, :users].each{|x| DB[x].delete}
DB[:users].insert(:password_hash=>BCrypt::Password.create("pass"), :name=>"default", :num_register_entries=>35, :id=>1)
DB[:users].insert(:password_hash=>BCrypt::Password.create("pass2"), :name=>"test", :num_register_entries=>35, :id=>2)
DB[:account_types].insert(:name=>"Asset", :id=>1)
DB[:account_types].insert(:name=>"Liability", :id=>2)
DB[:account_types].insert(:name=>"Income", :id=>3)
DB[:account_types].insert(:name=>"Expense", :id=>4)
DB[:accounts].insert(:user_id=>2, :balance=>0, :account_type_id=>1, :name=>"Test", :hidden=>false, :description=>"", :id=>5)
DB[:accounts].insert(:user_id=>2, :balance=>0, :account_type_id=>2, :name=>"Test Liability", :hidden=>false, :description=>"", :id=>6)
DB[:accounts].insert(:user_id=>1, :balance=>0, :account_type_id=>2, :name=>"Credit Card", :hidden=>false, :description=>"", :id=>2)
DB[:accounts].insert(:user_id=>1, :balance=>0, :account_type_id=>1, :name=>"Checking", :hidden=>false, :description=>"", :id=>1)
DB[:accounts].insert(:user_id=>1, :balance=>0, :account_type_id=>4, :name=>"Food", :hidden=>false, :description=>"", :id=>4)
DB[:accounts].insert(:user_id=>1, :balance=>0, :account_type_id=>3, :name=>"Salary", :hidden=>false, :description=>"", :id=>3)
DB[:entities].insert(:user_id=>1, :name=>"Restaurant", :id=>2)
DB[:entities].insert(:user_id=>1, :name=>"Employer", :id=>1)
DB[:entities].insert(:user_id=>1, :name=>"Card", :id=>3)
DB[:entities].insert(:user_id=>2, :name=>"Test", :id=>4)
DB[:entries].insert(:credit_account_id=>6, :reference=>"", :user_id=>2, :entity_id=>4, :cleared=>false, :amount=>100, :memo=>"", :date=>'2008-06-11', :debit_account_id=>5, :id=>1)
Entries = DB[:entries].filter(:user_id => 1)

PORT = ENV['PORT'] || 8989
SLEEP_TIME = Float(ENV['SLEEP_TIME'] || 0.5)

require 'minitest/autorun'

Capybara.default_driver = :webkit
Capybara.default_selector = :css
Capybara.server_port = PORT
#Capybara::Webkit.configure do |config|
#  config.debug = true
#end

class Minitest::Spec
  include Capybara::DSL

  def wait
    sleep SLEEP_TIME
  end

  def remove_id(hash)
    h = hash.dup
    h.delete(:id)
    h
  end
end

describe "SPAM" do
  it "should have a working ajax" do 
    Headless.ly do
      visit("http://127.0.0.1:#{PORT}/")
      fill_in 'Username', :with=>'default'
      fill_in 'Password', :with=>'pass'
      click_on 'Login'

      find('#nav-register').click_link('Registers')
      find('#nav-register').click_link('Checking')
      page.title.must_equal 'SPAM - Checking Register'
      find('h3').text.must_equal 'Showing 35 Most Recent Entries'
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
      click_on 'Add'

      wait
      entry = Entries.first
      remove_id(entry).must_equal(:date=>Date.new(2008,6,6), :reference=>'DEP', :entity_id=>1, :credit_account_id=>3, :debit_account_id=>1, :memo=>'Check', :amount=>BigDecimal.new('1000'), :cleared=>false, :user_id=>1)

      page.all("div#content form table tbody tr").last.all('td').map(&:text).must_equal '2008-06-06/DEP/Employer/Salary/Check//$1000.00/$1000.00/Modify'.split('/')
      click_on 'Modify'

      wait
      fill_in "entry[date]", :with=>'2008-06-07'
      fill_in "entry[reference]", :with=>'1000'
      fill_in "entity[name]", :with=>'Card'
      select 'Credit Card'
      fill_in "entry[memo]", :with=>'Payment'
      fill_in "entry[amount]", :with=>'-1000'
      check 'entry[cleared]'
      click_on 'Update'

      wait
      Entries[:id => entry[:id]].must_equal(:date=>Date.new(2008,6,7), :reference=>'1000', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment', :amount=>BigDecimal.new('1000'), :cleared=>true, :user_id=>1, :id=>entry[:id])
      page.all("div#content form table tbody tr").last.all('td').map(&:text).must_equal '2008-06-07/1000/Card/Credit Card/Payment/R/$-1000.00/$-1000.00/Modify'.split('/')
      
      click_on 'Modify'
      wait
      click_on 'Add'

      wait
      fill_in "entry[date]", :with=>'2008-06-08'
      fill_in "entry[reference]", :with=>'1001'
      fill_in "entity[name]", :with=>'Card'

      wait
      find('div.acResults ul li').click

      wait
      fill_in "entry[memo]", :with=>'Payment2'
      click_on 'Add'

      wait
      remove_id(Entries.order(:id).last).must_equal(:date=>Date.new(2008,6,8), :reference=>'1001', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment2', :amount=>BigDecimal.new('1000'), :cleared=>false, :user_id=>1)
      Entries.delete
      @entry_id = Entries.insert(:date=>Date.new(2008,06,07), :reference=>'1000', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment', :amount=>BigDecimal.new('1000'), :cleared=>false, :user_id=>1)

      find('#nav-reconcile').click_link('Reconcile')
      find('#nav-reconcile').click_link('Checking')
      form = find('div#content form')
      form.first('table').all('tr td').map{|x| x.text.strip}.must_equal "Unreconciled Balance/$0.00/Reconciling Changes/$0.00/Reconciled Balance/$0.00/Off By/$0.00/Reconcile To/// ".split('/')[0...-1]
      form.all('caption').map(&:text).must_equal 'Debit Entries/Credit Entries'.split('/')
      form.all('table').last.all('thead th').map(&:text).must_equal %w'C Date Num Entity Amount'
      form.all('table').last.all('tbody td').map(&:text).must_equal '/2008-06-07/1000/Card/$1000.00'.split('/')

      check "entries[#{@entry_id}]"
      fill_in 'reconcile_to', :with=>'-1000.00'
      click_on 'Auto-Reconcile'

      wait
      page.find("input#credit_#{@entry_id}")[:checked].must_equal 'true'

      click_on 'Clear Entries'

      wait
      Entries.first[:cleared].must_equal true
      page.all("input#credit_#{@entry_id}").size.must_equal 0
      page.first('table').all('td').map{|x| x.text.strip}.must_equal "Unreconciled Balance/$-1000.00/Reconciling Changes/$0.00/Reconciled Balance/$-1000.00/Off By/$-1000.00/Reconcile To/// ".split('/')[0...-1]
    end
  end
end    
