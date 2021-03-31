create or replace type active_obj is object (
    total_active_cases number,
    mild_condition number,
    serious_case number
);
/

create or replace type closed_obj is object (
    total_closed_case number,
    recovered_case number,
    deaths number
);
/

create or replace type country_meta_obj is object (
    position number,
    country varchar2(50),
    cases number,
    today_cases number,
    deaths number,
    today_deaths number
);
/

create or replace type active_cases is table of active_obj;
/

create or replace type closed_cases is table of closed_obj;
/

create or replace type country_meta_tbl is table of country_meta_obj;
/
