require ::File.expand_path('../models',  __FILE__)

require 'roda'
require 'rack/protection'
require 'rack/csrf'
require 'json'

class String
  def html_safe
    self
  end
end

class Spam < Roda
  unless secret = ENV['SECRET_TOKEN']
    if File.exist?('secret_token.txt')
      secret = File.read('secret_token.txt')
    else
      raise StandardError, "cannot load secret token"
    end
  end

  use Rack::Session::Cookie, :secret=>secret, :key => '_spam_session'
  use Rack::Csrf
  use Rack::Static, :urls=>%w'/images /javascripts /stylesheets /favicon.ico', :root=>'public'
  use Rack::Protection

  plugin :not_found
  plugin :error_handler
  plugin :render, :cache=>false
  plugin :flash
  plugin :h

  plugin :autoforme do
    inline_mtm_associations :all
    association_links :all_except_mtm

    model Account do
      columns [:name, :account_type, :hidden, :description]
      order :name
      display_name :short_name
      column_options :description=>{:as=>:textarea, :cols=>'50', :rows=>'4'}
      association_links [:recent_credit_entries, :recent_debit_entries]
      session_value :user_id
    end
    model Entity do
      columns [:name]
      order :name
      display_name :short_name
      association_links [:recent_entries]
      autocomplete_options({})
      session_value :user_id
    end
    model Entry do
      columns [:date, :reference, :entity, :credit_account, :debit_account, :amount, :memo, :cleared]
      order [:date, :reference, :amount].map{|s| Sequel.desc(s)}
      display_name :scaffold_name
      eager_graph [:entity, :credit_account, :debit_account]
      autocomplete_options(:display=>Sequel.lit("reference || date::TEXT || entity.name ||  debit_account.name || credit_account.name || entries.amount::TEXT"))
      session_value :user_id
    end
  end

  plugin :not_found do
    File.read("public/404.html")
  end

  ::Forme.register_config(:mine, :base=>:default, :labeler=>:explicit, :wrapper=>:div)
  ::Forme.default_config = :mine

  BY_YEAR_COND = Proc.new{|k| Sequel.~(Sequel.extract(:year, :entries__date) => k)}

  route do |r|
    if session[:user_id]
      @navigation_accounts = userAccount.unhidden.register_accounts
    end

    r.get '' do
      view 'login'
    end

    r.post 'login' do
      flash[:notice] = unless session[:user_id] = User.login_user_id(r['username'], r['password'])
        'Incorrect username or password.'
      else
        'You have been logged in.'
      end
      r.redirect '/'
    end

    r.post 'logout' do
      session.clear
      flash[:notice] = 'You have been logged out.'
      r.redirect '/'
    end

    unless session[:user_id]
      flash[:notice] = 'You need to login'
      r.redirect '/'
    end


    r.on 'reports', :method=>:get do
      r.is 'balance_sheet' do
        @assets, @liabilities = userAccount.register_accounts.exclude(Sequel.&(:hidden, :balance=>0)).all.partition{|x| x.account_type_id == 1}
        view 'balance_sheet'
      end
      
      r.is 'income_expense' do
        income_expense_report
        view 'income_expense'
      end
      
      r.is 'net_worth' do
        account = accounts_ds.select(*account_sums(1=>:assets, 2=>:liabilities)).first
        @assets, @liabilities = account[:assets].to_f, -account[:liabilities].to_f
        income_expense_report
        view 'net_worth'
      end
      
      r.is 'earning_spending' do
        if setup_month_headers
          @accounts = accounts_entries_ds.select(:accounts__name, *by_account_select{|k| Sequel.~(@age.extract(:month) => (@i+=1))}).
           filter(:accounts__account_type_id=>[3,4]).
           filter(@age < Sequel.cast('1 year', :interval)).
           group(:accounts__account_type_id, :accounts__name).order(Sequel.desc(:account_type_id), :name).all
        end
        view 'earning_spending'
      end

      r.is 'earning_spending_by_entity' do
        if setup_month_headers
          @accounts = entities_entries_ds.select(:entities__name, *by_entity_select{|k| Sequel.~(@age.extract(:month) => (@i+=1))}).
           filter(@age < Sequel.cast('1 year', :interval)).
           filter(Sequel.or(:d__account_type_id => [3,4], :c__account_type_id => [3,4]) & Sequel.or(:d__account_type_id => nil, :c__account_type_id => nil)).
           group(:entities__name).order(:name).all
        end
        view 'earning_spending'
      end

      r.is 'yearly_earning_spending_by_entity' do
        if setup_year_headers
          @accounts = entities_entries_ds.select(:entities__name, *by_entity_select(&BY_YEAR_COND)).
           filter(Sequel.or(:d__account_type_id => [3,4], :c__account_type_id => [3,4]) & Sequel.or(:d__account_type_id => nil, :c__account_type_id => nil)).
           group(:entities__name).order(:name).all
        end
        view 'earning_spending'
      end

      r.is 'yearly_earning_spending' do
        if setup_year_headers
          @accounts = accounts_entries_ds.select(:accounts__name, *by_account_select(&BY_YEAR_COND)).
           filter(:accounts__account_type_id=>[3,4]).
           group(:accounts__account_type_id, :accounts__name).order(Sequel.desc(:account_type_id), :name).all
        end
        view 'earning_spending'
      end
    end

    r.on 'update' do
      r.get do
        r.is 'auto_complete_for_entity_name/:id' do |id|
          @entities = userEntity.auto_complete(r['q'], id)
          if @entities.length > 0
            render(:inline => '<%= @entities.join("\n") %>')
          else
            ''
          end
        end
        
        r.is 'auto_reconcile' do
          auto_reconcile
        end
        
        r.is /modify_entry(?:\/(\d+))?/ do |id|
          @account = user_account(r['register_account_id'])
          @accounts = userAccount.for_select
          @selected_entry_id = r['selected_entry_id'].to_i if r['selected_entry_id'].to_i > 0

          if @selected_entry_id
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
            json.to_json
          else
            @show_num_entries = num_register_entries
            view 'register'
          end
        end

        r.is 'other_account_for_entry/:id' do |id|
          h = {}
          if r['entity'] and account = user_account(id) and entry = account.last_entry_for_entity(r['entity'])
            entry.main_account = account
            h = {:account_id=>entry.other_account.id, :amount=>entry.amount}
          end
          h.to_json
        end

        r.is 'reconcile/:id' do |id|
          @account = user_account(id)
          view 'reconcile'
        end

        r.is 'register/:id' do |id|
          @account = user_account(id)
          @accounts = userAccount.for_select
          @show_num_entries = ((r['show'] and r['show'].to_i != 0) ? r['show'].to_i : num_register_entries)
          @show_num_entries = nil if @show_num_entries < 1
          @check_number = @account.next_check_number
          view 'register'
        end
      end

      r.post do
        r.is 'add_entry' do
          @account = user_account(r['register_account_id'])
          @accounts = userAccount.for_select
          if r['update']
            next update_register_entry
          end
          @entry = Entry.new(r['entry'])
          @entry.user_id = session[:user_id]
          save_entry
          @check_number = (r['entry']['reference'] =~ /\A\d+\z/) ? r['entry']['reference'].next : ''

          if json_requested?
            [
              ['set_value', '#selected_entry_id', ''],
              ['replace_html', '#new_entry', render('_new_register_entry', :locals=>{:time=>@entry.date})],
              ['insert_html', '#new_entry', "<tr id='entry_#{@entry.id}'>#{render('_register_entry', :locals=>{:entry=>@entry})}</tr>"],
              ['replace_html', '#results', 'Added entry'],
              ['autocompleter'],
              ['resort']
            ].to_json
          else
            r.redirect "/update/register/#{@account.id}"
          end
        end

        r.is 'clear_entries' do
          if r['auto_reconcile'] && !request.xhr?
            next auto_reconcile
          end

          userEntry.filter(:id=>r['entries'].keys.collect{|i|i.to_i}).update(:cleared => true)

          if json_requested?
            @account = user_account(r['id'])
            [
              ['replace_html', '#off_by', @account.unreconciled_balance.to_money],
              ['replace_html', '#reconcile_changes', '$0.00'],
              ['set_value', '#reconcile_to', '$0.00'],
              ['replace_html', '#balance', @account.unreconciled_balance.to_money],
              ['replace_html', '#debit_entries', render('_reconcile_table', :locals=>{:entry_type=>'debit'})],
              ['replace_html', '#credit_entries', render('_reconcile_table', :locals=>{:entry_type=>'credit'})],
              ['replace_html', '#results', 'Cleared entries']
            ].to_json
          else
            r.redirect "/update/reconcile/#{r['id']}"
          end
        end
      end
    end

    r.is "change_password" do
      r.get do
        view 'change_password'
      end

      r.post do
        flash[:notice] = if r['password'] && r['password2']
          if r['password'].length < 6
            "Password too short, use at least 6 characters, preferably 10 or more."
          elsif r['password'] != r['password2']
            "Passwords don't match, please try again."
          else
            user = User[session[:user_id]]
            user.password = r['password']
            if user.save
              page = '/'
              'Password updated.'
            else
              "Can't update account."
            end
          end
        else
          "No password provided, so can't change it."
        end

        r.redirect(page||'/change_password')
      end
    end

    autoforme
  end

  private

  def balance_sheet_rows(accounts)
    accounts.collect{|account| "<tr><td class='account_name'>#{h account.name}</td><td class='money'>#{account.money_balance}</td></tr>" }.join("\n").html_safe
  end

  def get_navigation_accounts
    @navigation_accounts = userAccount.unhidden.register_accounts if session[:user_id]
  end
    
  def userAccount
    Account.user(session[:user_id])
  end 

  def userEntity
    Entity.user(session[:user_id])
  end 

  def userEntry
    Entry.user(session[:user_id])
  end

  def income_expense_report
    ue = userEntry
    negative_map = {:income=>true, :expense=>false, :assets=>true, :liabilities=>false}
    @months = accounts_entries_ds.select((Sequel.extract(:year, :entries__date).cast_string + Sequel.function(:to_char, Sequel.extract(:month, :entries__date) * -1, '00')).as(:month),
      *{3=>:income, 4=>:expense, 1=>:assets, 2=>:liabilities}.collect{|i, aliaz| Sequel.function(:sum, Sequel.case([[Sequel.~(:account_type_id=>i),0], [debit_cond, Sequel.*(:amount, (negative_map[aliaz] ? -1 : 1))]], Sequel.*(:amount, (negative_map[aliaz] ? 1 : -1)))).as(aliaz)}).
      filter{entries__date > Sequel.cast('1 year 1 month', :interval) * -1 + ue.select(max(date))}.
      group(:month).reverse_order(:month).all
    @months.pop if @months.length > 12
  end

  def accounts_ds
    DB[:accounts].filter(:accounts__user_id=>session[:user_id])
  end

  def accounts_entries_ds
    accounts_ds.join(:entries, Sequel.or(:debit_account_id => :accounts__id, :credit_account_id => :accounts__id))
  end

  def account_sums(accounts)
    accounts.to_a.collect{|id, name| Sequel.function(:sum, Sequel.case({{:account_type_id=>id}=>:balance}, 0)).as(name)}
  end

  def by_account_select
    @headers.map{|k, v| Sequel.function(:sum, Sequel.case([[yield(k), 0], [debit_cond, Sequel.*(:amount, -1)]], :amount)).as(v)}
  end

  def by_entity_select
    @headers.map{|k, v| Sequel.function(:sum, Sequel.case([[yield(k), 0], [{:c__account_type_id => nil}, Sequel.*(:amount, -1)]], :amount)).as(v)}
  end

  def debit_cond
    {:debit_account_id=>:accounts__id}
  end

  def entities_entries_ds
    DB[:entities].join(:entries, :entity_id=>:id).
      left_join(:accounts___d, :id=>:entries__debit_account_id, :account_type_id=>[3,4]).
      left_join(:accounts___c, :id=>:entries__credit_account_id, :account_type_id=>[3,4])
  end

  def setup_month_headers
    @accounts, @headers = [], []
    if max_date = userEntry.get{max(date)}
      @headers = (0...12).map{|i| [(max_date << i).strftime('%B %Y'), :"month_#{i}"]}
      md = Sequel.cast(max_date.to_s, Date)
      @age = Sequel.function(:age, md + 1 - md.extract(:day).cast_numeric, Sequel.+(:entries__date, 1) - Sequel.extract(:day, :entries__date).cast_numeric)
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
    User[session[:user_id]].num_register_entries
  end

  def auto_reconcile
    r = request
    id = r['id']
    @reconcile_to = r['reconcile_to'].to_f
    @account = user_account(id)
    begin
      @entries = @account.entries_reconciling_to(@reconcile_to, (r['entries'] || {}).keys.collect{|i|i.to_i}, 15)
      if @entries
        @reconcile_changes = @reconcile_to - @account.unreconciled_balance if @entries
        @entries = @entries.map{|x| x.id}
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
      json.to_json
    else
      view 'reconcile'
    end
  end

  def save_entry
    r = request
    other_account = user_account(r['account']['id'])
    @entry[:debit_account_id], @entry[:credit_account_id] = ((r['entry']['amount'].to_f > 0) ? [@account.id, other_account.id] : [other_account.id, @account.id])
    @entry.amount = r['entry']['amount'].to_f.abs
    entity = userEntity[:name=>r['entity']['name']]
    if r['entity']['name'].length > 0 and not entity
      entity = Entity.new(r['entity'])
      entity.user_id = session[:user_id]
      entity.save
    end
    @entry[:entity_id] = entity.id
    @entry.save
    @account.reload()
    @entry.main_account = @account
  end

  def update_register_entry
    r = request
    @entry = user_entry(r['entry'].delete('id'))
    @entry.set(r['entry'])
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
      ].to_json
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
