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
    2 id,
    'Total Cases:' E,
    null F,
    null G,
    null H,
    'Deaths:' J,
    null M,
    'Recovered' N,
    null O
from dual
UNION ALL
SELECT 
    3 id, 
    sum(nvl(total_cases,0)) || '' total_cases, 
    null F,
    null G,
    null H,
    sum(nvl(deaths, 0)) || '' deaths,
    null M,
    sum(nvl(recovered, 0)) || '' recovered,
    null O
from covid
union ALL
select 
    8 id,
    null E,
    null F,
    null G,
    null H,
    null J,
    null M,
    'Closed Cases' N,
    null O
FROM dual
union ALL
select
    9 id,
    'Active' E,
    null F,
    null G,
    null H,
    null J,
    null M,
    null N,
    null O
from dual
UNION ALL
select 
    10 id,
    'Cases' E,
    null F,
    (select total_active_cases || '' from pkg_covid.get_active_cases()) G,
    null H,
    null J,
    null M,
    (select total_closed_case || '' from pkg_covid.get_closed_cases()) N,
    null O
from dual
union all
select
    11 id,
    null E,
    null F,
    'Currently Infected Patients' G,
    null H,
    null J,
    null M,
    'Cases which had an outcome' N,
    null O
from dual
union all
select 
    14 id,
    null E,
    (select mild_condition ||
        ' ('|| round(mild_condition*100/total_active_cases,2)||'%)' from pkg_covid.get_active_cases())F,
    null G,
    (select serious_case ||
        ' ('|| round(serious_case*100/total_active_cases,2)||'%)' from pkg_covid.get_active_cases()) H,
    null J,
    (select recovered_case ||' ('||round(recovered_case*100/total_closed_case,2)||'%)' from pkg_covid.get_closed_cases()) M,
    null N,
    (select deaths ||' ('||round(deaths*100/total_closed_case,2)||'%)' from pkg_covid.get_closed_cases()) O
from dual
union all
select 
    15 id,
    null E,
    'In Mild Condition' F,
    null G,
    'Serious or Critical' H,
    null J,
    'Recovered/Discharged' M,
    null N,
    'Deaths'
from dual
union all
select
    19 id,
    null E,
    (SELECT country||':'||position||'-total: '||cases||';today: '||today_cases||'-'||deaths||';today:'||today_deaths from pkg_covid.get_meta_of('Nepal')) F,
    null G,
    null H,
    null J,
    null M,
    null N,
    null
from dual;


create or replace vw_final
as
select 
    t.rank,
    t.country_name "Top 20",
    t.total_cases "Top 20 Cases",
    tc.E,
    tc.F,
    tc.G,
    tc.H,
    tc.J,
    tc.M,
    tc.N,
    tc.O,
    b.country_name "Bottom 20",
    b.total_cases "Bottom 20 Cases"
from 
v_top_20 t
full outer join vw_statistics tc
on t.rid = tc.id
full outer join v_bottom_20 b
on t.rid = b.rid
order by 1;
