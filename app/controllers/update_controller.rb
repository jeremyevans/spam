class UpdateController < ApplicationController
  scaffold :account, :suffix=>true
  scaffold :entity, :suffix=>true
  scaffold :entry, :suffix=>true
  auto_complete_for :entity, :name
  
  scaffold_merge(Account, true)
  scaffold_merge(Entity, true)

  def add_entry
    @account = Account.find(session[:account_id])
    @accounts = Account.for_select
    return update_entry if params['update']
    @entry = Entry.new(params[:entry])
    save_entry
    session[:next_check_number] = ((params[:entry][:reference] =~ /\d{4}/) ? params[:entry][:reference].next : '')
    render(:partial=>'add_entry', :locals=>{:entry=>@entry})
  end
  
  def clear_entries
    Entry.update_all("cleared = TRUE", "id IN (#{params[:entries].keys.collect{|i|i.to_i.to_s}.join(',')})")
    redirect_to "/update/reconcile/#{params[:id]}"
  end
  
  def modify_entry
    @account = Account.find(session[:account_id])
    @accounts = Account.for_select
    if session[:entry_id]
      @other_entry = Entry.find(session[:entry_id])
      @other_entry.main_account = @account
    end
    if params[:id]
      @entry = Entry.find(params[:id])
      @entry.main_account = @account
      session[:entry_id] = @entry.id
    else session[:entry_id] = nil
    end
    render(:partial=>'modify_entry', :locals=>{:entry=>@entry, :other_entry=>@other_entry})
  end

  def other_account_for_entry
    @account = Account.find(session[:account_id])
    @entry = @account.last_entry_for_entity(params[:entity])
    @entry.main_account = @account
    render(:partial=>'update_account_and_amount', :locals=>{:entry=>@entry})
  end

  def reconcile
    @account = Account.find(params[:id])
  end

  def register
    @account = Account.find(params[:id])
    @accounts = Account.for_select
    @show_num_entries = ((params[:show] and params[:show].to_i != 0) ? params[:show].to_i : 25)
    @show_num_entries = nil if @show_num_entries < 1
    session[:account_id] = @account.id
    session[:entry_id] = nil
    session[:next_check_number] = @account.next_check_number
  end
  
  private

  def save_entry
    other_account = Account.find(params[:account][:id])
    @entry[:debit_account_id], @entry[:credit_account_id] = ((params[:entry][:amount].to_f > 0) ? [@account.id, other_account.id] : [other_account.id, @account.id])
    @entry.amount = params[:entry][:amount].to_f.abs
    entity = Entity.find_by_name(params[:entity][:name]) 
    entity = Entity.create(params[:entity]) if params[:entity][:name].length > 0 and not entity
    @entry[:entity_id] = entity.id
    @entry.save()
    @account.reload()
    @entry.main_account = @account
  end

  def update_entry
    session[:entry_id] = nil
    @entry = Entry.find(params[:entry][:id])
    @entry.attributes = params[:entry]
    save_entry
    render(:partial=>'update_entry', :locals=>{:entry=>@entry})
  end
end
