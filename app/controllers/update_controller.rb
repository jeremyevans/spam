class UpdateController < ApplicationController
  scaffold_all_models :only=>[Account, Entity, Entry]
  before_filter :require_login

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
      format.js
    end
  end
  
  def auto_complete_for_entity_name
    @items = userEntity.filter(:name.ilike("%#{params[:entity][:name]}%")).order(:name).limit(10).all
    if @items.length > 0
      render :text => "<ul>#{@items.collect{|x| "<li>#{x.name}</li>"}.join("\n")}</ul>", :layout=>false
    else
      render :nothing=>true
    end
  end
  
  def auto_reconcile
    @reconcile_to = params[:reconcile_to].to_f
    @account = user_account(params[:id])
    @entries = @account.entries_reconciling_to(@reconcile_to, (params[:entries] || {}).keys.collect{|i|i.to_i}, 15)
    if @entries
      @reconcile_changes = @reconcile_to - @account.unreconciled_balance if @entries
      @entries = Set.new(@entries.collect{|x| x.id})
    end
    respond_to do |format|
      format.html{render :action=>"reconcile"}
      format.js
    end
  end
  
  def clear_entries
    return auto_reconcile if params[:auto_reconcile] && !request.xhr?
    userEntry.filter(:id=>params[:entries].keys.collect{|i|i.to_i}).update(:cleared => true)
    respond_to do |format|
      format.html{redirect_to :action=>"reconcile", :id=>params[:id]}
      format.js{@account = user_account(params[:id]); render}
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
      format.js
    end
  end

  def other_account_for_entry
    return render(:nothing=>true) unless params[:entity]
    @account = user_account(params[:id])
    @entry = @account.last_entry_for_entity(params[:entity])
    @entry.main_account = @account
    respond_to do |format|
      format.js
    end
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
    @entry.set_with_params(params[:entry])
    save_entry
    respond_to do |format|
      format.html{redirect_to :action=>'register', :id=>@account.id}
      format.js{render(:action=>'update_register_entry')}
    end
  end

  def user_account(id)
    userAccount[:id=>id] || raise(Sequel::Error)
  end
  
  def user_entry(id)
    userEntry[:id=>id] || raise(Sequel::Error)
  end
end
