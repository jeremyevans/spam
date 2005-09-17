class QifController < ApplicationController
  def parse
    flash[:notice] = if params[:qif]
      accounts, entities, entries = parse_qif(params[:qif])
      make_active_records(accounts, entities, entries)
      "Imported #{accounts.length} accounts, #{entities.length} entities, and #{entries.length} entries"
    else "No qif file provided"
    end
    redirect_to :action=>"import"
  end
  
  private
  def account_name(contents)
    contents.length > 0 ? contents.sub(/^\[/,'').sub(/\]$/,'') : 'Misc'
  end

  def account_type(entry, current_account = false)
    "#{(current_account ^ (entry[:amount] > 0)) ? 'credit' : 'debit'}_account".to_sym
  end

  def add_entry(entry, account, entries, entry_hashes, accounts, boc)
    return if entry[:amount] == 0
    entry[account_type(entry, true)] = account[:name]
    entry[account_type(entry)] = 'Misc' if entry[:debit_account] == entry[:credit_account]
    entry[:amount] = entry[:amount].abs
    entries.push(entry) unless duplicate_entry_hash?(entry, entry_hashes, accounts, boc)
    entry_hashes[entry_hash(entry)] = true
  end

  def duplicate_entry_hash?(entry, entry_hashes, accounts, boc)
    entry_hashes.include?(entry_hash(entry)) and (accounts[entry[:debit_account]][:account_type] =~ boc) and (accounts[entry[:credit_account]][:account_type] =~ boc)
  end
  
  def entry_amount(contents)
    contents.gsub(',','').to_f
  end

  def entry_hash(entry)
    [entry[:date].to_s, entry[:debit_account], entry[:credit_account], entry[:amount]]
  end

  def make_active_records(accounts, entities, entries)
    ar_entities = {}
    Entry.transaction do
      entities.each{|entity| ar_entities[entity] = Entity.create({:name=>entity})}
      accounts.each{|key, account| accounts[key] = Account.create(account)}
      entries.each do |entry|
        entry[:entity_id] = ar_entities[entry[:entity]].id if entry[:entity] and entry[:entity].length > 0
        entry[:debit_account_id] = accounts[entry[:debit_account]] ? accounts[entry[:debit_account]].id : accounts['Misc'].id
        entry[:credit_account_id] = accounts[entry[:credit_account]] ? accounts[entry[:credit_account]].id : accounts['Misc'].id
        entry.delete(:debit_account)
        entry.delete(:credit_account)
        entry.delete(:entity)
        Entry.create(entry)
      end
    end
  end

  def parse_qif(qif)
    state = nil
    account = nil
    entry = nil
    split = nil
    accounts = Hash.new
    entries = []
    entry_hashes = Hash.new
    entities = []
    line_splitter = Regexp.new('^(.)(.*)$')
    aoc = Regexp.new('^(?:acc|cat)$')
    coa = Regexp.new('^(?:Type:Cat|Account)$')
    eos = Regexp.new('^(?:entry|split)$') 
    boc = Regexp.new('^(?:Bank|CCard)$')
    
    qif.each do |line|
      type, contents = line_splitter.match(line.strip)[1,2]
      case type
        when '!'
          entry = nil
          account = nil if contents =~ coa
          state = case contents
            when 'Type:Cat' then 'cat'
            when 'Account' then 'acc'
            when /Type:(Bank|CCard)/ 
              entry = {}
              'entry'
            else nil
          end
        when '^'
          case state
            when eos
              state = 'entry'
              add_entry(entry, account, entries, entry_hashes, accounts, boc)
              entry = {}
          end
        when '$'
          case state
            when 'split' then entry[:amount] = entry_amount(contents)
          end
        when 'C'
          case state
            when 'entry' then entry[:cleared] = true
          end
        when 'D'
          case state
            when 'entry'
              entry[:date] = parse_qif_date(contents)
          end
        when 'E'
          case state
            when 'cat' then account[:account_type] = 'Expense'
          end
        when 'I'
          case state
            when 'cat' then account[:account_type] = 'Income'
          end
        when 'L'
          case state
            when 'acc' then account[:credit_limit] = entry_amount(contents)
            when 'entry' then entry[account_type(entry)] = account_name(contents)
          end
        when 'M'
          case state
            when 'entry' then entry[:memo] = contents
          end
        when 'N'
          case state
            when aoc 
              account = accounts[contents] ||= Hash[:account_type=>'Expense']
              account[:name] = contents
            when 'entry' then entry[:reference] = contents
          end
        when 'P'
          case state
            when 'entry'
              entry[:entity] = contents
              entities.push(contents) unless entities.include?(contents)
          end
        when 'S'
          case state
            when 'entry' 
              state = 'split'
              entry[account_type(entry)] = account_name(contents)
            when 'split'
              add_entry(entry, account, entries, entry_hashes, accounts, boc)
              entry = entry.dup
              entry[account_type(entry)] = account_name(contents)
          end
        when 'T'
          case state
            when 'acc' then account[:account_type] = contents
            when 'cat' then account[:description] = contents
            when 'entry' then entry[:amount] = entry_amount(contents)
          end
      end
    end
    [accounts, entities, entries]
  end

  def parse_qif_date(contents)
    month, day, year = contents.split(/\/|\'/).collect{|p|p.to_i}
    Date.new((year + (year < 10 ?  2000 : 1900)), month, day)
  end
end
