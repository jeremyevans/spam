CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    account_type TEXT CHECK (account_type IN ('Bank','CCard','Income','Expense')),
    credit_limit DECIMAL(10,2) CHECK (credit_limit > 0),
    balance DECIMAL(10,2) DEFAULT 0 NOT NULL,
    description TEXT,
    hidden BOOLEAN DEFAULT FALSE
) WITHOUT OIDS;

CREATE TABLE entities (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
) WITHOUT OIDS;

CREATE TABLE entries (
    id SERIAL PRIMARY KEY,
    debit_account_id INTEGER REFERENCES accounts(id) NOT NULL,
    credit_account_id INTEGER REFERENCES accounts(id) NOT NULL,
    entity_id INTEGER REFERENCES entities(id),
    reference TEXT,
    date DATE DEFAULT CURRENT_DATE,
    amount DECIMAL(10,2) CHECK (amount > 0) NOT NULL,
    cleared BOOLEAN DEFAULT FALSE,
    memo TEXT
    CHECK (debit_account_id != credit_account_id)
) WITHOUT OIDS;

CREATE UNIQUE INDEX accounts_namei ON accounts (lower(name));
CREATE UNIQUE INDEX entities_namei ON accounts (lower(name));

CREATE FUNCTION update_account_balance() RETURNS TRIGGER AS '
    BEGIN
        IF (TG_OP = ''DELETE'' OR TG_OP = ''UPDATE'') THEN 
            UPDATE accounts SET balance = balance - OLD.amount WHERE id = OLD.debit_account_id;
            UPDATE accounts SET balance = balance + OLD.amount WHERE id = OLD.credit_account_id;
        END IF;
        IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
            UPDATE accounts SET balance = balance + NEW.amount WHERE id = NEW.debit_account_id;
            UPDATE accounts SET balance = balance - NEW.amount WHERE id = NEW.credit_account_id;
        END IF;
        RETURN NEW;
    END;
' LANGUAGE plpgsql;

CREATE TRIGGER update_account_balance BEFORE INSERT OR UPDATE OR DELETE ON entries
    FOR EACH ROW EXECUTE PROCEDURE update_account_balance();
