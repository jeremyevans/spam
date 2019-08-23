BEGIN;

CREATE TABLE account_types (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
) WITHOUT OIDS;

INSERT INTO account_types (id, name) VALUES (1, 'Asset');
INSERT INTO account_types (id, name) VALUES (2, 'Liability');
INSERT INTO account_types (id, name) VALUES (3, 'Income');
INSERT INTO account_types (id, name) VALUES (4, 'Expense');
SELECT setval('account_types_id_seq', 4);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    num_register_entries INTEGER DEFAULT 50 NOT NULL
) WITHOUT OIDS;

CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    user_id INTEGER REFERENCES users NOT NULL,
    account_type_id INTEGER REFERENCES account_types NOT NULL,
    balance DECIMAL(10,2) DEFAULT 0 NOT NULL,
    description TEXT,
    hidden BOOLEAN DEFAULT FALSE
) WITHOUT OIDS;

CREATE TABLE entities (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users NOT NULL,
    name TEXT NOT NULL
) WITHOUT OIDS;

CREATE TABLE entries (
    id SERIAL PRIMARY KEY,
    debit_account_id INTEGER REFERENCES accounts NOT NULL,
    credit_account_id INTEGER REFERENCES accounts NOT NULL,
    entity_id INTEGER REFERENCES entities,
    user_id INTEGER REFERENCES users NOT NULL,
    reference TEXT,
    date DATE DEFAULT CURRENT_DATE,
    amount DECIMAL(10,2) CHECK (amount > 0) NOT NULL,
    cleared BOOLEAN DEFAULT FALSE,
    memo TEXT
    CHECK (debit_account_id != credit_account_id)
) WITHOUT OIDS;

CREATE TABLE subusers (
    user_id INTEGER REFERENCES users NOT NULL,
    sub_user_id INTEGER REFERENCES users NOT NULL,
    PRIMARY KEY (user_id, sub_user_id)
) WITHOUT OIDS;

CREATE UNIQUE INDEX accounts_namei ON accounts (user_id, lower(name));
CREATE UNIQUE INDEX entities_namei ON entities (user_id, lower(name));
CREATE INDEX entries_user_date ON entries (user_id, date);

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
        IF (TG_OP = ''DELETE'') THEN
            RETURN OLD;
        END IF;
        RETURN NEW;
    END;
' LANGUAGE plpgsql;

CREATE FUNCTION check_entity_and_accounts() RETURNS TRIGGER AS '
    DECLARE
        check_user_id INTEGER;
    BEGIN
        SELECT user_id INTO STRICT check_user_id FROM accounts WHERE id = NEW.debit_account_id;
        IF check_user_id != NEW.user_id THEN
            RAISE EXCEPTION ''User IDs do not match: Entry: %, Debit Account: %'', NEW.user_id, check_user_id;
        END IF;
        SELECT user_id INTO STRICT check_user_id FROM accounts WHERE id = NEW.debit_account_id;
        IF check_user_id != NEW.user_id THEN
            RAISE EXCEPTION ''User IDs do not match: Entry: %, Credit Account: %'', NEW.user_id, check_user_id;
        END IF;
        SELECT user_id INTO STRICT check_user_id FROM entities WHERE id = NEW.entity_id;
        IF check_user_id != NEW.user_id THEN
            RAISE EXCEPTION ''User IDs do not match: Entry: %, Entity: %'', NEW.user_id, check_user_id;
        END IF;
        RETURN NEW;
    END;
' LANGUAGE plpgsql;

CREATE FUNCTION no_updating_user_id() RETURNS TRIGGER AS '
    BEGIN
        IF NEW.user_id != OLD.user_id THEN 
            RAISE EXCEPTION ''Attempted user_id update: Old: %, New: %'', OLD.user_id, NEW.user_id;
        END IF;
        RETURN NEW;
    END;
' LANGUAGE plpgsql;

CREATE TRIGGER update_account_balance BEFORE INSERT OR UPDATE OR DELETE ON entries
    FOR EACH ROW EXECUTE PROCEDURE update_account_balance();

CREATE TRIGGER check_entity_and_accounts BEFORE INSERT ON entries
    FOR EACH ROW EXECUTE PROCEDURE check_entity_and_accounts();

CREATE TRIGGER no_updating_accounts_user_id BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE PROCEDURE no_updating_user_id();
    
CREATE TRIGGER no_updating_entities_user_id BEFORE UPDATE ON entities
    FOR EACH ROW EXECUTE PROCEDURE no_updating_user_id();
    
CREATE TRIGGER no_updating_entries_user_id BEFORE UPDATE ON entries
    FOR EACH ROW EXECUTE PROCEDURE no_updating_user_id();

COMMIT;
