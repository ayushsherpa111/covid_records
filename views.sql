-- top 20
CREATE OR REPLACE VIEW v_top_20
AS
    SELECT  row_number() over(order by total_cases desc) rid,country_name, total_cases,rank() over(order by total_cases desc) rank
    from covid
    fetch next 20 rows only;

CREATE OR REPLACE VIEW v_bottom_20
AS
    SELECT row_number() over(order by total_cases) rid,country_name,total_cases, rank() over(order by total_cases) rank
    from covid
    fetch next 20 rows only;

-- active cases
CREATE MATERIALIZED VIEW mv_active_cases
BUILD IMMEDIATE
REFRESH FORCE ON COMMIT
AS 
SELECT country_name, 
nvl(total_cases,0)-nvl(deaths,0)-nvl(recovered,0) active_cases,
nvl(serious, 0) serious
from covid;

CREATE OR REPLACE VIEW vw_statistics
AS
SELECT 
    4 id, 
    'total_cases' total,
    'total dead' sub,
    'total recovered' subb 
from dual
UNION
SELECT 
    5 id, 
    cast(sum(nvl(total_cases,0)) as varchar2(50)) total_cases, 
    cast(sum(nvl(deaths, 0)) as varchar2(50)) deaths,
    cast(sum(nvl(recovered, 0)) as varchar2(50)) recovered
from covid
union
select 
    7 id,
    'Total Active Cases',
    'Total Mild Cases',
    'Total Serious Case'
FROM dual
union
SELECT 
    8 id,
    cast(total_active_cases as varchar2(50)),
    mild_condition ||
        ' ('|| round(mild_condition*100/total_active_cases,2)||'%)' mild,
    serious_case ||
        ' (' || round(serious_case*100/total_active_cases, 2)|| '%)' serious
from pkg_covid.get_active_cases()
UNION
SELECT 
    10 id,
    'Total Closed',
    'Total Recovered',
    'Total Dead'
FROM dual
UNION
SELECT 
    11 id,
    total_closed_case||'',
    recovered_case ||
        ' ('||round(recovered_case*100/total_closed_case,2)||'%)' recovered,
    deaths || 
        ' (' || round(deaths*100/total_closed_case, 2) || '%)' deaths
from pkg_covid.get_closed_cases()
UNION
SELECT 
    13 id, 
    'Country-Position',
    'Total Cases and Cases Today',
    'Total Deaths and Deaths Today'
FROM dual
union
SELECT 
    14 id, 
    country||'-'||position,
    cases || '- today: ' || today_cases,
    deaths || '- today: ' || today_deaths
from pkg_covid.get_meta_of('Nepal');


