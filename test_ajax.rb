# frozen_string_literal: true
require 'capybara'
require 'capybara/dsl'
require "capybara/cuprite"
require 'puma/cli'
require 'nio'
require 'securerandom'

ENV['RACK_ENV'] = 'test'
ENV['AJAX_TESTS'] = '1'
ENV['SPAM_SESSION_SECRET'] = SecureRandom.base64(48)

require_relative 'spam'
require_relative 'test_data'
require_relative 'spec_helper'

port = 8989
db_name = Spam::DB.get{current_database.function}
raise "Doesn't look like a test database (#{db_name}), not running tests" unless db_name =~ /test\z/

entries = Spam::DB[:entries].filter(:user_id => 1)

Capybara.exact = true
Capybara.default_selector = :css
Capybara.server_port = port
Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1200, 800], xvfb: true)
end
Capybara.current_driver = :cuprite

queue = Queue.new
server = Puma::CLI.new(['-s', '-b', "tcp://127.0.0.1:#{port}", '-t', '1:1', 'config.ru'])
server.launcher.events.on_booted{queue.push(nil)}
Thread.new do
  server.launcher.run
end
queue.pop

if ENV['UNUSED_ASSOCIATION_COVERAGE']
  at_exit do
    require 'coverage'
    Coverage.start(methods: true)
    at_exit do
      Spam::Model.update_associations_coverage(Coverage.result)
    end
  end
end

class Minitest::HooksSpec
  remove_method(:around)
  around do |&block|
    Spam::DB.transaction(:rollback=>:always, :savepoint=>true, :auto_savepoint=>true) do |c|
      Spam::DB.temporarily_release_connection(c) do
        super(&block)
      end
    end
  end
end

describe "SPAM" do
  include Capybara::DSL
  include Spam::TestData

  def wait
    sleep(Float(ENV['SLEEP_TIME'] || 0.5))
  end

  before(:all) do |&block|
    load_test_data
  end

  def log
    Spam::DB.loggers.first.level = Logger::INFO
    yield
  ensure
    Spam::DB.loggers.first.level = Logger::WARN
  end

  def remove_id(hash)
    h = hash.dup
    h.delete(:id)
    h
  end

  define_method(:visit) do |path|
    super("http://127.0.0.1:#{port}#{path}")
  end

  it "should have working ajax" do 
    visit "/"
    fill_in 'Username', :with=>'default'
    fill_in 'Password', :with=>'pass'
    click_button 'Login'
    page.title.must_equal 'SPAM'

    visit '/update/register/1'
    page.title.must_equal 'SPAM - Checking Register'
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
    click_on 'Add'

    wait
    entry = entries.first
    remove_id(entry).must_equal(:date=>Date.new(2008,6,6), :reference=>'DEP', :entity_id=>1, :credit_account_id=>3, :debit_account_id=>1, :memo=>'Check', :amount=>BigDecimal('1000'), :cleared=>false, :user_id=>1)

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
    entries[:id => entry[:id]].must_equal(:date=>Date.new(2008,6,7), :reference=>'1000', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment', :amount=>BigDecimal('1000'), :cleared=>true, :user_id=>1, :id=>entry[:id])
    page.all("div#content form table tbody tr").last.all('td').map(&:text).must_equal '2008-06-07/1000/Card/Credit Card/Payment/R/$-1000.00/$-1000.00/Modify'.split('/')
    
    click_on 'Modify'
    wait
    click_on 'Add'

    wait
    fill_in "entry[date]", :with=>'2008-06-08'
    fill_in "entry[reference]", :with=>'1001'
    fill_in "entity[name]", :with=>'Card'

    wait
    find("#entity_name").send_keys(:left, :down, :tab)

    wait
    fill_in "entry[memo]", :with=>'Payment2'
    click_on 'Add'

    wait
    remove_id(entries.order(:id).last).must_equal(:date=>Date.new(2008,6,8), :reference=>'1001', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment2', :amount=>BigDecimal('1000'), :cleared=>false, :user_id=>1)
    entries.delete
    @entry_id = entries.insert(:date=>Date.new(2008,06,07), :reference=>'1000', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment', :amount=>BigDecimal('1000'), :cleared=>false, :user_id=>1)

    visit '/update/reconcile/1'
    form = find('div#content form')
    form.first('table').all('tr td').map{|x| x.text.strip}.must_equal "Previous Reconciled Balance/$0.00/Reconciling Changes/$0.00/New Reconciled Balance/$0.00/Expected Reconciled Balance//Off By/$0.00// ".split('/')[0...-1]
    form.all('caption').map(&:text).must_equal ['Credit Entries']
    form.all('table').last.all('thead th').map(&:text).must_equal %w'C Date Num Entity Amount'
    form.all('table').last.all('tbody td').map(&:text).must_equal '/2008-06-07/1000/Card/$1000.00'.split('/')

    check "entries[#{@entry_id}]"
    fill_in 'reconcile_to', :with=>'-1000.00'
    click_on 'Auto-Reconcile'

    wait
    page.find("input#credit_#{@entry_id}")[:checked].must_equal true

    click_on 'Clear Entries'

    wait
    entries.first[:cleared].must_equal true
    page.all("input#credit_#{@entry_id}").size.must_equal 0
    page.first('table').all('tr td').map{|x| x.text.strip}.must_equal "Previous Reconciled Balance/$-1000.00/Reconciling Changes/$0.00/New Reconciled Balance/$-1000.00/Expected Reconciled Balance//Off By/$0.00// ".split('/')[0...-1]
#ensure
#p page.driver.browser.error_messages
  end
end    
