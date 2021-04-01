CREATE OR REPLACE TRIGGER trig_log_new_cases
BEFORE UPDATE
ON covid
FOR EACH ROW
BEGIN
    INSERT INTO newrecords(country_name, new_cases, new_deaths) 
    values(:new.country_name, :new.total_cases-:old.total_cases, :new.deaths-:old.deaths);
end trig_log_new_cases;
/
