CREATE OR REPLACE PACKAGE pkg_covid as
    procedure add_new_cases(country_name varchar2,new_case number,new_death number, total_recovered number, serious_case number);
    function get_active_cases return active_cases pipelined;
    function get_closed_cases return closed_cases pipelined;
    function get_meta_of(country varchar2) return country_meta_tbl;
end pkg_covid;
/


CREATE OR REPLACE PACKAGE BODY pkg_covid
as 
    procedure add_new_cases(country in varchar2,new_case in number, new_death in number, total_recovered in number, serious_case in number)
    as
    begin
        UPDATE covid
        set 
            total_cases = total_cases + new_case,
            deaths = deaths + new_death,
            recovered = nvl(total_recovered, recovered),
            serious = nvl(serious_case, serious)
        where upper(country_name)=upper(country);

        exception when others then dbms_output.put_line('failed transaction');
    end add_new_cases;

    function get_active_cases return active_cases
    PIPELINED as
        mild_cases number;
        total_cases number;
        total_serious number;
    begin
        SELECT 
            sum(active_cases), 
            sum(serious) 
        INTO total_cases, total_serious 
        FROM mv_active_cases;

        mild_cases := total_cases - total_serious;
        pipe row(active_obj(total_cases, mild_cases, total_serious));
        return;
    end get_active_cases;

    function get_closed_cases return closed_cases
    PIPELINED as
        closed_case number;
        total_recovered number;
        total_deaths number;
    begin
        SELECT sum(recovered), sum(deaths)
        into total_recovered, total_deaths from covid;
        closed_case := total_deaths + total_recovered;
        PIPE ROW(closed_obj(closed_case, total_recovered, total_deaths));
        return;
    end get_closed_cases;


    function get_meta_of(country varchar2) return country_meta_tbl
    as
        meta_tbl country_meta_tbl := country_meta_tbl();
        meta country_meta_obj;
    begin
        meta_tbl.extend(1);

        meta := get_rank(country);
        meta_tbl(1) := meta;
        return meta_tbl;
    end get_meta_of;
end pkg_covid;
/
