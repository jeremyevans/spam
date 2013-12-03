class UpdateController < ApplicationController
  before_filter :require_login
  before_filter :require_post, :only=>[:add_entry, :clear_entries]

  AutoForme.for(:rails, self) do
    model_type :sequel
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

  def add_entry
    @account = user_account(params[:register_account_id])
    @accounts = userAccount.for_select
    return update_register_entry if params['update']
    @entry = Entry.new(params[:entry])
    @entry.user_id = session[:user_id]
    save_entry
    @check_number = (params[:entry][:reference] =~ /\A\d+\z/) ? params[:entry][:reference].next : ''
    respond_to do |format|
      format.html{redirect_to :action=>'register', :id=>@account.id}
      format.json do
        json = [
          ['set_value', '#selected_entry_id', ''],
          ['replace_html', '#new_entry', render_to_string(:partial=>'new_register_entry', :formats => [:html], :locals=>{:time=>@entry.date})],
          ['insert_html', '#new_entry', "<tr id='entry_#{@entry.id}'>#{render_to_string(:partial=>'register_entry', :formats => [:html], :locals=>{:entry=>@entry})}</tr>"],
          ['replace_html', '#results', 'Added entry'],
          ['autocompleter'],
          ['resort']
        ]
        render :json=>json
      end
    end
  end
  
  def auto_complete_for_entity_name
    @entities = userEntity.auto_complete(params[:q], params[:id])
    if @entities.length > 0
      render :inline => '<%=raw @entities.join("\n") %>', :layout=>false
    else
      render :nothing=>true
    end
  end
  
  def auto_reconcile
    @reconcile_to = params[:reconcile_to].to_f
    @account = user_account(params[:id])
    begin
      @entries = @account.entries_reconciling_to(@reconcile_to, (params[:entries] || {}).keys.collect{|i|i.to_i}, 15)
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
    respond_to do |format|
      format.html{render :action=>"reconcile"}
      format.json do
        if @entries
          json = [
            ['replace_html', '#off_by', '$0.00'],
            ['replace_html', '#reconcile_changes', @reconcile_changes.to_money],
            ['replace_html', '#debit_entries', render_to_string(:partial=>'reconcile_table', :formats => [:html], :locals=>{:entry_type=>'debit'})],
            ['replace_html', '#credit_entries', render_to_string(:partial=>'reconcile_table', :formats => [:html], :locals=>{:entry_type=>'credit'})]
          ]
        else
          json = []
        end
        json << ['replace_html', '#results', @error_message]
        render :json=>json
      end
    end
  end
  
  def clear_entries
    return auto_reconcile if params[:auto_reconcile] && !request.xhr?
    userEntry.filter(:id=>params[:entries].keys.collect{|i|i.to_i}).update(:cleared => true)
    respond_to do |format|
      format.html{redirect_to :action=>"reconcile", :id=>params[:id]}
      format.json do
        @account = user_account(params[:id])
        json = [
          ['replace_html', '#off_by', @account.unreconciled_balance.to_money],
          ['replace_html', '#reconcile_changes', '$0.00'],
          ['set_value', '#reconcile_to', '$0.00'],
          ['replace_html', '#balance', @account.unreconciled_balance.to_money],
          ['replace_html', '#debit_entries', render_to_string(:partial=>'reconcile_table', :formats => [:html], :locals=>{:entry_type=>'debit'})],
          ['replace_html', '#credit_entries', render_to_string(:partial=>'reconcile_table', :formats => [:html], :locals=>{:entry_type=>'credit'})],
          ['replace_html', '#results', 'Cleared entries']
        ]
        render :json=>json
      end
    end
  end
  
  def modify_entry
    @account = user_account(params[:register_account_id])
    @accounts = userAccount.for_select
    @selected_entry_id = params[:selected_entry_id].to_i if params[:selected_entry_id].to_i > 0
    if @selected_entry_id
      @other_entry = user_entry(@selected_entry_id)
      @other_entry.main_account = @account
    end
    if params[:id]
      @entry = user_entry(params[:id])
      @entry.main_account = @account
      @selected_entry_id = @entry.id
    else @selected_entry_id = nil
    end
    respond_to do |format|
      format.html{@show_num_entries = num_register_entries; render :action=>'register'}
      format.json do
        json = []
        json << ['set_value', '#selected_entry_id', @selected_entry_id]
        json << ['replace_html', '#new_entry', render_to_string(:partial=>"#{@entry ? 'blank' : 'new'}_register_entry", :formats => [:html], :locals=>{:entry=>@entry})]
        json << ['replace_html', "#entry_#{@other_entry.id}", render_to_string(:partial=>'register_entry', :formats => [:html], :locals=>{:entry=>@other_entry})] if @other_entry
        json << ['resort']
        json << ['replace_html', "#entry_#{@entry.id}", render_to_string(:partial=>'modify_register_entry', :formats => [:html], :locals=>{:entry=>@entry})] if @entry
        json << ['replace_html', '#results', @entry ? 'Modify entry' : 'Add entry']
        json << ['autocompleter']
        render :json=>json
      end
    end
  end

  def other_account_for_entry
    h = {}
    if params[:entity] and account = user_account(params[:id]) and entry = account.last_entry_for_entity(params[:entity])
      entry.main_account = account
      h = {:account_id=>entry.other_account.id, :amount=>entry.amount}
    end
    render :json=>h
  end

  def reconcile
    @account = user_account(params[:id])
  end

  def register
    @account = user_account(params[:id])
    @accounts = userAccount.for_select
    @show_num_entries = ((params[:show] and params[:show].to_i != 0) ? params[:show].to_i : num_register_entries)
    @show_num_entries = nil if @show_num_entries < 1
    @check_number = @account.next_check_number
  end
  
  private

  def num_register_entries
    User[session[:user_id]].num_register_entries
  end

  def save_entry
    other_account = user_account(params[:account][:id])
    @entry[:debit_account_id], @entry[:credit_account_id] = ((params[:entry][:amount].to_f > 0) ? [@account.id, other_account.id] : [other_account.id, @account.id])
    @entry.amount = params[:entry][:amount].to_f.abs
    entity = userEntity[:name=>params[:entity][:name]]
    if params[:entity][:name].length > 0 and not entity
      entity = Entity.new(params[:entity])
      entity.user_id = session[:user_id]
      entity.save
    end
    @entry[:entity_id] = entity.id
    @entry.save
    @account.reload()
    @entry.main_account = @account
  end

  def update_register_entry
    @entry = user_entry(params[:entry].delete(:id))
    @entry.set(params[:entry])
    save_entry
    @entry.reload
    @entry.main_account = @account
    respond_to do |format|
      format.html{redirect_to :action=>'register', :id=>@account.id}
      format.json do
        json = [
          ['set_value', '#selected_entry_id', ''],
          ['replace_html', '#new_entry', render_to_string(:partial=>'new_register_entry', :formats => [:html], :locals=>{:time=>@entry.date})],
          ['replace_html', "#entry_#{@entry.id}", render_to_string(:partial=>'register_entry', :formats => [:html], :locals=>{:entry=>@entry})],
          ['replace_html', '#results', 'Updated entry'],
          ['autocompleter'],
          ['resort']
        ]
        render :json=>json
      end
    end
  end

  def user_account(id)
    userAccount[:id=>id] || raise(Sequel::Error)
  end
  
  def user_entry(id)
    userEntry[:id=>id] || raise(Sequel::Error)
  end
end
