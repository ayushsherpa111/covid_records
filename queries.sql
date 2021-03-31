-- total cases
SELECT 1 id, sum(nvl(total_cases,0)) total_cases from covid

-- total deaths
SELECT 1 id, sum(nvl(deaths,0)) total_cases from covid;

-- total recovered
SELECT 1 id, sum(nvl(recovered,0)) total_cases from covid;

select sum(act) from (
    select country_name, nvl(total_cases,0)-nvl(deaths,0)-nvl(recovered,0) act from covid
);

with active_with_percent as (
SELECT 
    1 id,
    total_active_cases, 
    mild_condition || 
        ' ('|| round(mild_condition*100/total_active_cases,2)||')' mild,
    serious_case || 
        ' (' || round(serious_case*100/total_active_cases, 2)|| ')' serious
from pkg_covid.get_active_cases()
), closed_with_percent as (
SELECT 
    1 id,
    total_closed_case,
    recovered_case ||
        ' ('||round(recovered_case*100/total_closed_case,2)||')' recovered,
    deaths || 
        ' (' || round(deaths*100/total_closed_case, 2) || ')' deaths
from pkg_covid.get_closed_cases()
) select 
    t.country_name top_20,
    b.country_name bottom_20,
    a.total_active_cases, 
    a.mild,
    a.serious,
    c.total_closed_case,
    c.recovered,
    c.deaths
from 
v_top_20 t
full outer join v_bottom_20 b
on t.rank = b.rank
full outer join
active_with_percent a
on a.id = t.rank
full outer join closed_with_percent c
on a.id = c.id;


