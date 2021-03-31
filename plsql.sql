CREATE OR REPLACE PACKAGE pkg_covid as
    procedure add_new_cases;
    function get_active_cases return active_cases pipelined;
    function get_closed_cases return closed_cases pipelined;
    function get_meta_of(country varchar2) return
end pkg_covid;
/


CREATE OR REPLACE PACKAGE BODY pkg_covid
as 
    procedure add_new_cases
    as
    begin
        dbms_output.put_line('test');
    end add_new_cases;

    function get_active_cases return active_cases
    PIPELINED as
        mild_cases number;
        total_cases number;
        total_serious number;
    begin
        select sum(active_cases), sum(serious) into total_cases,total_serious from mv_active_cases;
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


end pkg_covid;
/
