-- SQM
CREATE OR REPLACE FUNCTION get_rank(country varchar2) return country_meta_obj
IS 
    meta country_meta_obj;
BEGIN
    SELECT country_meta_obj(rnk,country_name, total_cases, new_cases, deaths, new_deaths) 
    INTO meta
    from (
        SELECT rank() over(order by total_cases desc) rnk, 
            c.country_name, 
            nvl(deaths,0) deaths, 
            nvl(total_cases, 0) total_cases,
            nvl(new_cases,0) new_cases,
            nvl(new_deaths,0) new_deaths
        from covid c
        left join newrecords n
        on c.country_name = n.country_name
        and to_char(n.date_added,'yyyymmdd') = to_char(current_date,'yyyymmdd')
    ) where upper(country_name)=upper(country);
    return meta;
END get_rank;
/
