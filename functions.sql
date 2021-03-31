-- SQM
CREATE OR REPLACE FUNCTION get_rank(country varchar2) return country_meta_obj
IS 
    meta country_meta_obj;
BEGIN
    SELECT country_meta_obj(rnk,country_name, total_cases, 0, deaths, 0) 
    INTO meta
    from (
        SELECT rank() over(order by total_cases desc) rnk, country_name, nvl(deaths,0) deaths, nvl(total_cases, 0) total_cases from covid
    ) where upper(country_name)=upper(country);
    return meta;
END get_rank;
/
