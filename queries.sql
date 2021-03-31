-- total cases
SELECT 1 id, sum(nvl(total_cases,0)) total_cases from covid

-- total deaths
SELECT 1 id, sum(nvl(deaths,0)) total_cases from covid;

-- total recovered
SELECT 1 id, sum(nvl(recovered,0)) total_cases from covid;

select sum(act) from (
    select country_name, nvl(total_cases,0)-nvl(deaths,0)-nvl(recovered,0) act from covid
);


select 
    t.rank,
    t.country_name "Top 20",
    t.total_cases "Total Cases",
    tc.total,
    tc.sub,
    tc.subb,
    b.country_name "Bottom 20",
    b.total_cases "Total Cases"
from 
v_top_20 t
full outer join vw_statistics tc
on t.rid = tc.id
full outer join v_bottom_20 b
on t.rid = b.rid
order by 1;
