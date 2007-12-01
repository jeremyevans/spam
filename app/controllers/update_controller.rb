require 'set'
class UpdateController < ApplicationController
  scaffold_all_models :only=>[:account, :entity, :entry]
  before_filter :require_login

  def add_entry
    @account = find_account_with_user_id(session[:account_id])
    @accounts = Account.for_select(session[:user_id])
    return update_register_entry if params['update']
    @entry = Entry.new(params[:entry])
    @entry.user_id = session[:user_id]
    save_entry
    session[:next_check_number] = ((params[:entry][:reference] =~ /\d{4}/) ? params[:entry][:reference].next : '')
    respond_to do |format|
      format.html{redirect_to :action=>'register', :id=>@account.id}
      format.js
    end
  end
  
  def auto_complete_for_entity_name
    @items = Entity.find(:all, :conditions=>["user_id = ? AND name ILIKE ?", session[:user_id], "%#{params[:entity][:name]}%"], :limit=>10, :order=>'name')
    if @items.length > 0
      render :inline => "<%= auto_complete_result 'items', 'name' %>"
    else
      render :nothing=>true
    end
  end
  
  def auto_reconcile
    @reconcile_to = params[:reconcile_to].to_f
    @account = find_account_with_user_id(params[:id])
    @entries = @account.entries_reconciling_to(@reconcile_to, (params[:entries] || {}).keys.collect{|i|i.to_i}, 15)
    if @entries
      @reconcile_changes = @reconcile_to - @account.unreconciled_balance if @entries
      @entries = Set.new(@entries.collect(&:id))
    end
    respond_to do |format|
      format.html{render :action=>"reconcile"}
      format.js{render :action=>'auto_reconcile'}
    end
  end
  
  def clear_entries
    return auto_reconcile if params[:auto_reconcile] && !request.xhr?
    Entry.update_all("cleared = TRUE", "user_id = #{session[:user_id]} AND id IN (#{params[:entries].keys.collect{|i|i.to_i}.join(',')})")
    respond_to do |format|
      format.html{redirect_to :action=>"reconcile", :id=>params[:id]}
      format.js{@account = find_account_with_user_id(params[:id]); render}
    end
  end
  
  def modify_entry
    @account = find_account_with_user_id(session[:account_id])
    @accounts = Account.for_select(session[:user_id])
    if session[:entry_id]
      @other_entry = find_entry_with_user_id(session[:entry_id])
      @other_entry.main_account = @account
    end
    if params[:id]
      @entry = find_entry_with_user_id(params[:id])
      @entry.main_account = @account
      session[:entry_id] = @entry.id
    else session[:entry_id] = nil
    end
    respond_to do |format|
      format.html{@show_num_entries = User.find(session[:user_id]).num_register_entries; render :action=>'register'}
      format.js
    end
  end

  def other_account_for_entry
    return render(:nothing=>true) unless params[:entity]
    @account = find_account_with_user_id(session[:account_id])
    @entry = @account.last_entry_for_entity(params[:entity])
    @entry.main_account = @account
  end

  def reconcile
    @account = find_account_with_user_id(params[:id])
  end

  def register
    @account = find_account_with_user_id(params[:id])
    @accounts = Account.for_select(session[:user_id])
    @show_num_entries = ((params[:show] and params[:show].to_i != 0) ? params[:show].to_i : User.find(session[:user_id]).num_register_entries)
    @show_num_entries = nil if @show_num_entries < 1
    session[:account_id] = @account.id
    session[:entry_id] = nil
    session[:next_check_number] = @account.next_check_number
  end
  
  private

  def find_account_with_user_id(id)
    Account.find_with_user_id(session[:user_id], id)
  end
  
  def find_entry_with_user_id(id)
    Entry.find_with_user_id(session[:user_id], id)
  end

  def save_entry
    other_account = find_account_with_user_id(params[:account][:id])
    @entry[:debit_account_id], @entry[:credit_account_id] = ((params[:entry][:amount].to_f > 0) ? [@account.id, other_account.id] : [other_account.id, @account.id])
    @entry.amount = params[:entry][:amount].to_f.abs
    entity = Entity.find(:first, :conditions=>['name = ? AND user_id = ?', params[:entity][:name], session[:user_id]]) 
    if params[:entity][:name].length > 0 and not entity
      entity = Entity.new(params[:entity])
      entity.user_id = session[:user_id]
      entity.save!
    end
    @entry[:entity_id] = entity.id
    @entry.save!
    @account.reload()
    @entry.main_account = @account
  end

  def update_register_entry
    session[:entry_id] = nil
    @entry = find_entry_with_user_id(params[:entry][:id])
    @entry.attributes = params[:entry]
    save_entry
    respond_to do |format|
      format.html{redirect_to :action=>'register', :id=>@account.id}
      format.js{render(:action=>'update_register_entry')}
    end
  end
end
