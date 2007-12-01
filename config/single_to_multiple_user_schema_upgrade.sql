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
    salt CHAR(40) NOT NULL,
    password CHAR(40) NOT NULL,
    num_register_entries INTEGER DEFAULT 35 NOT NULL
) WITHOUT OIDS;

INSERT INTO users (id, name, salt, password) VALUES (1, 'default',  '', '');
SELECT setval('users_id_seq', 1);

ALTER TABLE accounts ADD account_type_id INTEGER REFERENCES account_types (id);
UPDATE accounts SET account_type_id = 1 WHERE account_type = 'Bank';
UPDATE accounts SET account_type_id = 2 WHERE account_type = 'CCard';
UPDATE accounts SET account_type_id = 3 WHERE account_type = 'Income';
UPDATE accounts SET account_type_id = 4 WHERE account_type = 'Expense';
ALTER TABLE accounts DROP account_type;
UPDATE accounts SET description = (CASE 
    WHEN description IS NULL THEN 'Credit Limit: ' || credit_limit::text 
    ELSE description || E'\nCredit Limit: ' || credit_limit::text 
    END) WHERE credit_limit IS NOT NULL;
ALTER TABLE accounts DROP credit_limit;
ALTER TABLE accounts ALTER account_type_id SET NOT NULL;

ALTER TABLE accounts ADD user_id INTEGER REFERENCES users (id);
UPDATE accounts SET user_id = 1;
ALTER TABLE accounts ALTER user_id SET NOT NULL;

ALTER TABLE entities ADD user_id INTEGER REFERENCES users (id);
UPDATE entities SET user_id = 1;
ALTER TABLE entities ALTER user_id SET NOT NULL;

ALTER TABLE entries ADD user_id INTEGER REFERENCES users (id);
UPDATE entries SET user_id = 1;
ALTER TABLE entries ALTER user_id SET NOT NULL;

DROP INDEX accounts_namei;
DROP INDEX accounts_name_key;
DROP INDEX entities_namei;
DROP INDEX entities_name_key;
CREATE UNIQUE INDEX accounts_namei ON accounts (user_id, lower(name));
CREATE UNIQUE INDEX entities_namei ON entities (user_id, lower(name));
CREATE INDEX entries_user_date ON entries (user_id, date);

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

CREATE TRIGGER check_entity_and_accounts BEFORE INSERT ON entries
    FOR EACH ROW EXECUTE PROCEDURE check_entity_and_accounts();

CREATE TRIGGER no_updating_accounts_user_id BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE PROCEDURE no_updating_user_id();
    
CREATE TRIGGER no_updating_entities_user_id BEFORE UPDATE ON entities
    FOR EACH ROW EXECUTE PROCEDURE no_updating_user_id();
    
CREATE TRIGGER no_updating_entries_user_id BEFORE UPDATE ON entries
    FOR EACH ROW EXECUTE PROCEDURE no_updating_user_id();

COMMIT;
