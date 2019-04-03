require_relative 'models'

require 'roda'
require 'securerandom'

module Spam
class App < Roda
  opts[:root] = File.dirname(__FILE__)
  opts[:check_dynamic_arity] = false
  opts[:check_arity] = :warn

  plugin :direct_call

  plugin :strip_path_prefix if ENV['SPAM_STRIP_PATH_PREFIX']

  plugin :route_csrf

  plugin :public, :gzip=>true
  plugin :not_found
  plugin :error_handler
  plugin :render, :escape=>true
  plugin :assets,
    :css=>%w'bootstrap-3.3.7.customized.min.css jquery.autocomplete.css scaffold_associations_tree.css spam.scss',
    :js=>%w'jquery-1.11.1.min.js bootstrap.min.js jquery.autocomplete.js autoforme.js application.js scaffold_associations_tree.js',
    :css_opts=>{:style=>:compressed, :cache=>false},
    :compiled_js_dir=>'javascripts',
    :compiled_css_dir=>'stylesheets',
    :compiled_path=>nil,
    :precompiled=>File.expand_path('../compiled_assets.json', __FILE__),
    :prefix=>nil,
    :gzip=>true
  plugin :render_each
  plugin :flash
  plugin :h
  plugin :json
  plugin :symbol_views
  plugin :disallow_file_uploads
  plugin :request_aref, :raise
  plugin :typecast_params
  alias tp typecast_params

  plugin :autoforme do
    inline_mtm_associations :all
    association_links :all_except_mtm

    model Account do
      class_display_name 'Account'
      columns [:name, :account_type, :hidden, :description]
      order :name
      display_name :short_name
      column_options :description=>{:as=>:textarea, :cols=>'50', :rows=>'4'}
      association_links [:recent_credit_entries, :recent_debit_entries]
      session_value 'user_id'
    end
    model Entity do
      class_display_name 'Entity'
      columns [:name]
      order :name
      display_name :short_name
      association_links [:recent_entries]
      autocomplete_options({})
      session_value 'user_id'
    end
    model Entry do
      class_display_name 'Entry'
      columns [:date, :reference, :entity, :credit_account, :debit_account, :amount, :memo, :cleared]
      order [:date, :reference, :amount].map{|s| Sequel.desc(s)}
      display_name :scaffold_name
      eager_graph [:entity, :credit_account, :debit_account]
      autocomplete_options(:display=>Sequel.lit("reference || date::TEXT || entity.name ||  debit_account.name || credit_account.name || entries.amount::TEXT"))
      session_value 'user_id'
    end
  end

  plugin :not_found do
    File.read("public/404.html")
  end

  logger = case ENV['RACK_ENV']
  when 'development', 'test' # Remove development after Unicorn 5.5+
    Class.new{def write(_) end}.new
  else
    $stderr
  end
  plugin :common_logger, logger

  error do |e|
    case e
    when Roda::RodaPlugins::TypecastParams::Error
      response.status = 400
      view(:content=>"<h1>Invalid parameter submitted: #{h e.param_name}</h1>")
    else
      $stderr.puts "#{e.class}: #{e.message}", e.backtrace
      view(:content=>"<h1>Internal Server Error</h1>")
    end
  end

  plugin :rodauth, :csrf=>:route_csrf do
    db DB
    enable :login, :logout
    enable :change_password unless ENV['SPAM_DEMO']
    session_key 'user_id'
    login_param 'username'
    login_label 'Username'
    login_column :name
    accounts_table :users
    account_password_hash_column :password_hash
    title_instance_variable :@pagetitle
  end
  precompile_rodauth_templates

  ::Forme.register_config(:mine, :base=>:default, :labeler=>:explicit, :wrapper=>:div)
  ::Forme.default_config = :mine

  BY_YEAR_COND = Proc.new{|k| Sequel.~(Sequel.extract(:year, Sequel[:entries][:date]) => k)}

  plugin :content_security_policy do |csp|
    csp.default_src :none
    csp.style_src :self, :unsafe_inline
    csp.script_src :self
    csp.connect_src :self
    csp.img_src :self
    csp.form_action :self
    csp.base_uri :none
    csp.frame_ancestors :none
  end

  plugin :sessions,
    :key=>'spam.session',
    :secret=>ENV.delete('SPAM_SESSION_SECRET')

  plugin :hash_routes

  hash_routes :root do
    view "", :content=>''
  end

  hash_routes :reports do
    dispatch_from :root, "reports"

    get 'balance_sheet' do
      @assets, @liabilities = userAccount.register_accounts.exclude(Sequel.&(:hidden, :balance=>0)).all.partition{|x| x.account_type_id == 1}
      :balance_sheet
    end

    get 'income_expense' do
      income_expense_report
      :income_expense
    end
        
    get 'net_worth' do
      account = accounts_ds.select(*account_sums(1=>:assets, 2=>:liabilities)).first
      @assets, @liabilities = account[:assets].to_f, -account[:liabilities].to_f
      income_expense_report
      :net_worth
    end

    get 'earning_spending' do
      if setup_month_headers
        @accounts = accounts_entries_ds.select(Sequel[:accounts][:name], *by_account_select{|k| Sequel.~(@age.extract(:month) => (@i+=1))}).
         filter(Sequel[:accounts][:account_type_id]=>[3,4]).
         filter(@age < Sequel.cast('1 year', :interval)).
         group(Sequel[:accounts][:account_type_id], Sequel[:accounts][:name]).order(Sequel.desc(:account_type_id), :name).all
      end
      :earning_spending
    end

    get 'earning_spending_by_entity' do
      if setup_month_headers
        @accounts = entities_entries_ds.select(Sequel[:entities][:name], *by_entity_select{|k| Sequel.~(@age.extract(:month) => (@i+=1))}).
         filter(@age < Sequel.cast('1 year', :interval)).
         filter(Sequel.or(Sequel[:d][:account_type_id] => [3,4], Sequel[:c][:account_type_id] => [3,4]) & Sequel.or(Sequel[:d][:account_type_id] => nil, Sequel[:c][:account_type_id] => nil)).
         group(Sequel[:entities][:name]).order(:name).all
      end
      :earning_spending
    end

    get 'yearly_earning_spending_by_entity' do
      if setup_year_headers
        @accounts = entities_entries_ds.select(Sequel[:entities][:name], *by_entity_select(&BY_YEAR_COND)).
         filter(Sequel.or(Sequel[:d][:account_type_id] => [3,4], Sequel[:c][:account_type_id] => [3,4]) & Sequel.or(Sequel[:d][:account_type_id] => nil, Sequel[:c][:account_type_id] => nil)).
         group(Sequel[:entities][:name]).order(:name).all
      end
      :earning_spending
    end

    get 'yearly_earning_spending' do
      if setup_year_headers
        @accounts = accounts_entries_ds.select(Sequel[:accounts][:name], *by_account_select(&BY_YEAR_COND)).
         filter(Sequel[:accounts][:account_type_id]=>[3,4]).
         group(Sequel[:accounts][:account_type_id], Sequel[:accounts][:name]).order(Sequel.desc(:account_type_id), :name).all
      end
      :earning_spending
    end
  end

  hash_routes :update do
    dispatch_from :root, 'update'

    on 'auto_complete_for_entity_name' do |r|
      r.get Integer do |id|
        userEntity.auto_complete(tp.str!('q'), id).join("\n")
      end
    end
  
    get 'auto_reconcile' do
      auto_reconcile
    end
    
    on 'modify_entry' do |r|
      r.get [Integer, true] do |id|
        @account = user_account(tp.pos_int!('register_account_id'))
        @accounts = userAccount.for_select

        if @selected_entry_id = tp.pos_int('selected_entry_id')
          @other_entry = user_entry(@selected_entry_id)
          @other_entry.main_account = @account
        end

        if id
          @entry = user_entry(id)
          @entry.main_account = @account
          @selected_entry_id = @entry.id
        else
          @selected_entry_id = nil
        end

        if json_requested?
          json = []
          json << ['set_value', '#selected_entry_id', @selected_entry_id]
          json << ['replace_html', '#new_entry', render("_#{@entry ? 'blank' : 'new'}_register_entry", :locals=>{:entry=>@entry})]
          json << ['replace_html', "#entry_#{@other_entry.id}", render('_register_entry', :locals=>{:entry=>@other_entry})] if @other_entry
          json << ['resort']
          json << ['replace_html', "#entry_#{@entry.id}", render('_modify_register_entry', :locals=>{:entry=>@entry})] if @entry
          json << ['replace_html', '#results', @entry ? 'Modify entry' : 'Add entry']
          json << ['autocompleter']
          json
        else
          @show_num_entries = num_register_entries
          :register
        end
      end
    end

    on 'other_account_for_entry' do |r|
      r.get Integer do |id|
        h = {}
        if (entity = tp.nonempty_str('entity')) && (account = user_account(id)) && (entry = account.last_entry_for_entity(entity))
          entry.main_account = account
          h = {:account_id=>entry.other_account.id, :amount=>entry.amount.to_s('F')}
        end
        h
      end
    end

    on 'reconcile' do |r|
      r.get Integer do |id|
        @account = user_account(id)
        :reconcile
      end
    end

    on 'register' do |r|
      r.get Integer do |id|
        @account = user_account(id)
        @accounts = userAccount.for_select
        @show_num_entries = tp.pos_int('show', num_register_entries)
        @check_number = @account.next_check_number
        :register
      end
    end

    post 'add_entry' do
      @account = user_account(tp.pos_int!('register_account_id'))
      @accounts = userAccount.for_select
      if tp.present?('update')
        next update_register_entry
      end
      @entry = Entry.new(tp.Hash!('entry'))
      @entry.user_id = session['user_id']
      save_entry
      ref = tp['entry'].str!('reference')
      @check_number = (ref =~ /\A\d+\z/) ? ref.next : ''

      if json_requested?
        [
          ['set_value', '#selected_entry_id', ''],
          ['replace_html', '#new_entry', render('_new_register_entry', :locals=>{:time=>@entry.date})],
          ['insert_html', '#new_entry', "<tr id='entry_#{@entry.id}'>#{render('_register_entry', :locals=>{:entry=>@entry})}</tr>"],
          ['replace_html', '#results', 'Added entry'],
          ['autocompleter'],
          ['resort']
        ]
      else
        request.redirect "/update/register/#{@account.id}"
      end
    end

    post 'clear_entries' do
      if tp.present?('auto_reconcile') && !request.xhr?
        next auto_reconcile
      end

      userEntry.filter(:id=>tp.Hash!('entries').keys.collect(&:to_i)).update(:cleared => true)

      next unless account_id = tp.pos_int('id')

      if json_requested?
        @account = user_account(account_id)
        reconciled_balance = @account.unreconciled_balance.to_money
        [
          ['replace_html', '#reconcile_changes', '$0.00'],
          ['replace_html', '#balance', reconciled_balance],
          ['replace_html', '#reconciled_balance', reconciled_balance],
          ['set_value', '#reconcile_to', reconciled_balance],
          ['replace_html', '#off_by', '$0.00'],
          ['replace_html', '#debit_entries', render('_reconcile_table', :locals=>{:entry_type=>'debit'})],
          ['replace_html', '#credit_entries', render('_reconcile_table', :locals=>{:entry_type=>'credit'})],
          ['replace_html', '#results', 'Cleared entries'],
          ['setup_reconcile']
        ]
      elsif 
        request.redirect "/update/reconcile/#{account_id}"
      end
    end
  end

  route do |r|
    r.public
    r.assets
    check_csrf!
    r.rodauth
    rodauth.require_authentication

    @navigation_accounts = userAccount.unhidden.register_accounts

    r.hash_routes(:root)
    autoforme
  end

  private

  def balance_sheet_rows(accounts)
    accounts.collect{|account| "<tr><td class='account_name'>#{h account.name}</td><td class='money'>#{account.money_balance}</td></tr>" }.join("\n")
  end

  def get_navigation_accounts
    @navigation_accounts = userAccount.unhidden.register_accounts if session['user_id']
  end
    
  def userAccount
    Account.user(session['user_id'])
  end 

  def userEntity
    Entity.user(session['user_id'])
  end 

  def userEntry
    Entry.user(session['user_id'])
  end

  def income_expense_report
    ue = userEntry
    negative_map = {:income=>true, :expense=>false, :assets=>true, :liabilities=>false}
    @months = accounts_entries_ds.select((Sequel.extract(:year, Sequel[:entries][:date]).cast_string + Sequel.function(:to_char, Sequel.extract(:month, Sequel[:entries][:date]) * -1, '00')).as(:month),
      *{3=>:income, 4=>:expense, 1=>:assets, 2=>:liabilities}.collect{|i, aliaz| Sequel.function(:sum, Sequel.case([[Sequel.~(:account_type_id=>i),0], [debit_cond, Sequel.*(:amount, (negative_map[aliaz] ? -1 : 1))]], Sequel.*(:amount, (negative_map[aliaz] ? 1 : -1)))).as(aliaz)}).
      group(:month).reverse_order(:month).all
    @months.pop if @months.length > 12
  end

  def accounts_ds
    DB[:accounts].filter(Sequel[:accounts][:user_id]=>session['user_id'])
  end

  def accounts_entries_ds
    accounts_ds.join(:entries, Sequel.or(:debit_account_id => Sequel[:accounts][:id], :credit_account_id => Sequel[:accounts][:id]))
  end

  def account_sums(accounts)
    accounts.to_a.collect{|id, name| Sequel.function(:sum, Sequel.case({{:account_type_id=>id}=>:balance}, 0)).as(name)}
  end

  def by_account_select
    @headers.map{|k, v| Sequel.function(:sum, Sequel.case([[yield(k), 0], [debit_cond, Sequel.*(:amount, -1)]], :amount)).as(v)}
  end

  def by_entity_select
    @headers.map{|k, v| Sequel.function(:sum, Sequel.case([[yield(k), 0], [{Sequel[:c][:account_type_id] => nil}, Sequel.*(:amount, -1)]], :amount)).as(v)}
  end

  def debit_cond
    {:debit_account_id=>Sequel[:accounts][:id]}
  end

  def entities_entries_ds
    DB[:entities].join(:entries, :entity_id=>:id).
      left_join(Sequel[:accounts].as(:d), :id=>Sequel[:entries][:debit_account_id], :account_type_id=>[3,4]).
      left_join(Sequel[:accounts].as(:c), :id=>Sequel[:entries][:credit_account_id], :account_type_id=>[3,4])
  end

  def setup_month_headers
    @accounts, @headers = [], []
    if max_date = userEntry.get{max(date)}
      @headers = (0...12).map{|i| [(max_date << i).strftime('%B %Y'), :"month_#{i}"]}
      md = Sequel.cast(max_date.to_s, Date)
      @age = Sequel.function(:age, md + 1 - md.extract(:day).cast_numeric, Sequel.+(Sequel[:entries][:date], 1) - Sequel.extract(:day, Sequel[:entries][:date]).cast_numeric)
      @i = -1
      true
    else
      false
    end
  end

  def setup_year_headers
    @accounts = []
    @headers = userEntry.group(Sequel.extract(:year, :date)).reverse_order(:year).select_map(Sequel.extract(:year, :date).cast(Integer).as(:year))
    @headers.map!{|k| [k, :"year_#{k}"]}
    !@headers.empty?
  end

  def num_register_entries
    User[session['user_id']].num_register_entries
  end

  def auto_reconcile
    r = request
    id = tp.pos_int!('id')
    @reconcile_to = tp.float!('reconcile_to')
    @account = user_account(id)
    begin
      @entries = @account.entries_reconciling_to(@reconcile_to, (tp.Hash('entries', {})).keys.collect(&:to_i), 15)
      if @entries
        @reconcile_changes = @reconcile_to - @account.unreconciled_balance if @entries
        @entries = @entries.map(&:id)
        @error_message = "Autoreconciled account"
      else
        @error_message = "No combination of entries reconciles to #{@reconcile_to}"
      end
    rescue SubsetSum::TimeoutError
      @error_message = "Timeout while attempting to auto reconcile"
    end

    if json_requested?
      if @entries
        json = [
          ['replace_html', '#off_by', '$0.00'],
          ['replace_html', '#reconcile_changes', @reconcile_changes.to_money],
          ['replace_html', '#debit_entries', render('_reconcile_table', :locals=>{:entry_type=>'debit'})],
          ['replace_html', '#credit_entries', render('_reconcile_table', :locals=>{:entry_type=>'credit'})]
        ]
      else
        json = []
      end
      json << ['replace_html', '#results', @error_message]
      json << ['setup_reconcile']
      json
    else
      view 'reconcile'
    end
  end

  def save_entry
    r = request
    other_account = user_account(tp['account'].pos_int!('id'))
    amount = tp['entry'].float!('amount')
    @entry[:debit_account_id], @entry[:credit_account_id] = ((amount > 0) ? [@account.id, other_account.id] : [other_account.id, @account.id])
    @entry.amount = amount.abs
    if entity_name = tp['entity'].nonempty_str('name')
      unless entity = userEntity[:name=>entity_name]
        entity = Entity.new(tp.Hash!('entity'))
        entity.user_id = session['user_id']
        entity.save
      end
      @entry[:entity_id] = entity.id
    end
    @entry.save
    @account.reload
    @entry.main_account = @account
  end

  def update_register_entry
    r = request
    entry = tp.Hash!('entry')
    entry_id = tp['entry'].pos_int!('id')
    @entry = user_entry(entry_id)
    entry.delete('id')
    @entry.set(entry)
    save_entry
    @entry.reload
    @entry.main_account = @account

    if json_requested?
      [
        ['set_value', '#selected_entry_id', ''],
        ['replace_html', '#new_entry', render('_new_register_entry', :locals=>{:time=>@entry.date})],
        ['replace_html', "#entry_#{@entry.id}", render('_register_entry', :locals=>{:entry=>@entry})],
        ['replace_html', '#results', 'Updated entry'],
        ['autocompleter'],
        ['resort']
      ]
    else
      r.redirect "/update/register/#{@account.id}"
    end
  end

  def user_account(id)
    userAccount.with_pk(id.to_i)
  end
  
  def user_entry(id)
    userEntry.with_pk!(id.to_i)
  end

  def json_requested?
    env['HTTP_ACCEPT'] =~ /application\/json/
  end
end
end
