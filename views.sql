-- top 20
CREATE OR REPLACE VIEW v_top_20
AS
    SELECT country_name, rank() over(order by total_cases desc) rank
    from covid
    fetch next 20 rows only;

CREATE OR REPLACE VIEW v_bottom_20
AS
    SELECT country_name, rank() over(order by total_cases) rank
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
