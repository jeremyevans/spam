class UpdateController < ApplicationController
  scaffold_all_models
  auto_complete_for :entity, :name

  def add_entry
    @account = Account.find(session[:account_id])
    @accounts = Account.for_select
    return update_register_entry if params['update']
    @entry = Entry.new(params[:entry])
    save_entry
    session[:next_check_number] = ((params[:entry][:reference] =~ /\d{4}/) ? params[:entry][:reference].next : '')
    respond_to do |format|
      format.html{redirect_to :action=>'register', :id=>@account.id}
      format.js
    end
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
    respond_to do |format|
      format.html{@show_num_entries = 35; render :action=>'register'}
      format.js
    end
  end

  def other_account_for_entry
    @account = Account.find(session[:account_id])
    @entry = @account.last_entry_for_entity(params[:entity])
    @entry.main_account = @account
  end

  def reconcile
    @account = Account.find(params[:id])
  end

  def register
    @account = Account.find(params[:id])
    @accounts = Account.for_select
    @show_num_entries = ((params[:show] and params[:show].to_i != 0) ? params[:show].to_i : 35)
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

  def update_register_entry
    session[:entry_id] = nil
    @entry = Entry.find(params[:entry][:id])
    @entry.attributes = params[:entry]
    save_entry
    respond_to do |format|
      format.html{redirect_to :action=>'register', :id=>@account.id}
      format.js{render(:action=>'update_register_entry')}
    end
  end
end
