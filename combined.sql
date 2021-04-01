-- tables used
-- Main table to store stats
create table COVID (
   country_name varchar2(50) primary key,
   total_cases number,
   deaths number,
   recovered number,
   serious number
);

-- table to store new records that are added day by day basis
create table newrecords (
    date_added date default current_date,
    country_name varchar2(50) references COVID(country_name),
    new_cases number check(new_cases >= 0),
    new_deaths number check(new_deaths >= 0),
    primary key(date_added, country_name)
);

-- Types used in procedures
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

-- trigger to keep track of new casesnew cases
CREATE OR REPLACE TRIGGER trig_log_new_cases
BEFORE UPDATE
ON covid
FOR EACH ROW
BEGIN
    INSERT INTO newrecords(country_name, new_cases, new_deaths) 
    values(:new.country_name, :new.total_cases-:old.total_cases, :new.deaths-:old.deaths);
end trig_log_new_cases;
/

-- views
-- top 20
CREATE OR REPLACE VIEW v_top_20
AS
    SELECT  row_number() over(order by total_cases desc) rid,country_name, total_cases,rank() over(order by total_cases desc) rank
    from covid
    fetch next 20 rows only;

-- bottom 20
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

-- packages
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

-- view to get statistics
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

-- insert. how data is fed the first time
insert into covid(country_name, total_cases, deaths, recovered, serious) values('USA',30922914,562069,23348808,8592);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Brazil',12490362,310694,10879627,8318);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('India',11987860,161715,11330279,8944);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Russia',4519832,97740,4139128,2300);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('France',4508575,94465,289350,4791);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('UK',4333042,126592,3805416,615);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Italy',3532057,107933,2850889,3679);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Spain',3255324,75010,3016247,1830);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Turkey',3179115,30923,2939929,1886);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Germany',2776004,76419,2484600,3209);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Colombia',2375591,62790,2261373,1982);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Argentina',2301389,55368,2072228,3506);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Poland',2250991,51884,1798922,2894);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Mexico',2224767,201429,1759123,4798);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Iran',1855674,62397,1593219,3920);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Ukraine',1644063,31954,1300625,177);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('South Africa',1544466,52648,1471164,546);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Peru',1520973,51238,1432450,2301);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Czechia',1515029,25874,1315571,1800);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Indonesia',1496085,40449,1331400,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Netherlands',1252437,16465,null,646);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Chile',977243,22754,912058,2539);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Canada',964448,22873,898444,661);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Romania',936618,23114,837060,1386);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Belgium',866063,22870,56371,667);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Iraq',832428,14212,745935,492);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Israel',831897,6180,815721,458);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Portugal',820407,16837,775391,142);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Sweden',780018,13402,null,284);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Philippines',721892,13170,603154,785);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Pakistan',654591,14215,595929,3043);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Hungary',633861,19972,395790,1527);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Bangladesh',595714,8904,535641,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Switzerland',592217,10299,542535,159);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Serbia',585506,5190,488992,269);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Jordan',582133,6472,476090,729);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Austria',536465,9256,491619,519);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Morocco',494358,8798,482084,262);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Japan',466849,9031,441237,341);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Lebanon',458338,6058,360244,978);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('UAE',455197,1481,438706,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Saudi Arabia',388325,6650,376947,638);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Slovakia',357910,9496,255300,662);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Panama',353497,6090,342379,105);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Malaysia',341944,1255,326309,169);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Bulgaria',327770,12650,248904,769);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Ecuador',322699,16679,271847,534);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Belarus',318681,2219,309535,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Georgia',280301,3751,272219,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Nepal',276839,3027,272530,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Bolivia',269302,12165,217921,71);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Croatia',267222,5893,251237,121);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Azerbaijan',256201,3491,236151,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Greece',254031,7880,214527,728);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Dominican Republic',251983,3304,211044,151);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Tunisia',249703,8705,215195,281);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Kazakhstan',240381,2994,216380,221);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Palestine',236462,2581,210340,197);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Ireland',233937,4653,23364,65);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Denmark',228013,2414,216590,43);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Kuwait',227178,1279,211360,250);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Moldova',226521,4827,201769,339);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Costa Rica',215178,2931,191707,155);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Lithuania',213941,3551,197618,128);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Slovenia',212678,4018,196319,106);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Paraguay',206597,4003,169197,423);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Egypt',199364,11845,152642,90);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Ethiopia',198794,2784,153236,769);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Guatemala',193050,6794,174980,5);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Armenia',190317,3464,171506,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Honduras',187015,4557,71384,464);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Qatar',177774,284,162910,279);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Nigeria',162489,2041,150205,10);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Bosnia and Herzegovina',162032,6220,128241,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Libya',156849,2618,144964,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Oman',156087,1661,142420,145);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Venezuela',155663,1555,144229,162);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Myanmar',142385,3206,131789,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Bahrain',140818,513,132455,54);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Kenya',130214,2117,91754,121);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('North Macedonia',126230,3642,104345,124);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Albania',123641,2204,88899,46);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Algeria',116750,3077,81242,20);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Estonia',103630,868,77270,69);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('S. Korea',101757,1722,93855,104);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Latvia',101040,1878,92014,69);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Uruguay',95278,901,76030,273);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Norway',92858,656,74332,46);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Sri Lanka',92007,559,88623,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Ghana',90287,740,87137,40);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('China',90167,4636,85364,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Montenegro',90083,1245,81936,69);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Kyrgyzstan',88092,1495,84600,16);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Zambia',87872,1200,84347,90);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Uzbekistan',82340,626,80523,23);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Finland',76003,817,46000,59);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Cuba',72503,415,68499,65);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Mozambique',67011,762,55167,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('El Salvador',63766,1998,61009,35);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Luxembourg',60755,738,56318,21);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Singapore',60300,30,60113,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Afghanistan',56322,2472,50013,1108);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Cameroon',47669,721,35261,53);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Cyprus',44305,250,2057,51);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Namibia',43499,508,41292,37);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Ivory Coast',42861,232,38590,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Uganda',40767,335,40379,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Senegal',38520,1037,36753,33);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Botswana',38466,506,33903,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Jamaica',38227,570,17197,44);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Zimbabwe',36818,1519,34575,13);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Malawi',33458,1113,29585,33);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Sudan',29661,2028,23990,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Australia',29255,909,26269,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Malta',28875,387,27086,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Thailand',28734,94,27239,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('DRC',27930,739,25398,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Madagascar',23585,387,21636,26);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Maldives',23403,66,20618,103);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Angola',22031,533,20269,15);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Rwanda',21370,301,19741,7);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Guinea',19670,120,16425,24);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Mayotte',19306,154,2964,16);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Gabon',18777,111,16074,27);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('French Polynesia',18607,141,4842,2);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Syria',18356,1227,12257,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Mauritania',17756,448,16989,14);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Eswatini',17318,666,16389,6);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Cabo Verde',17018,165,16050,23);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('French Guiana',16922,89,9995,6);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Réunion',15561,102,14064,57);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Tajikistan',13308,90,13218,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Haiti',12736,251,10754,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Burkina Faso',12673,145,12330,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Belize',12415,317,12061,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Andorra',11850,115,11204,12);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Hong Kong',11447,205,11040,10);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Guadeloupe',11298,165,2242,8);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Somalia',10838,488,4678,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Lesotho',10686,315,4438,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('South Sudan',10098,108,9454,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Guyana',10072,225,8842,13);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Togo',9827,107,7699,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Mali',9773,376,6763,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Congo',9681,135,8208,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Aruba',9214,82,8455,8);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Suriname',9095,177,8577,5);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Bahamas',8935,188,7757,3);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Trinidad and Tobago',7954,142,7590,13);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Martinique',7710,49,98,5);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Curaçao',7335,30,5071,38);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Djibouti',7249,66,6250,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Benin',7100,90,6452,35);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Mongolia',7014,6,4341,34);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Equatorial Guinea',6902,102,6486,10);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Nicaragua',6629,177,4225,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Iceland',6163,29,6039,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Gambia',5401,163,5030,3);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Papua New Guinea',5184,45,846,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('CAR',5088,64,4957,2);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Niger',4987,185,4586,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('San Marino',4603,84,4000,9);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Chad',4501,160,4099,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Gibraltar',4273,94,4167,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Saint Lucia',4191,58,4099,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Seychelles',4084,20,3548,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Channel Islands',4046,86,3960,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Yemen',4033,851,1606,23);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Sierra Leone',3962,79,2800,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Comoros',3690,146,3510,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Guinea-Bissau',3630,61,2930,16);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Barbados',3609,41,3422,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Eritrea',3208,9,2970,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Liechtenstein',2658,56,2553,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Burundi',2657,6,773,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Vietnam',2591,35,2308,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('New Zealand',2482,26,2381,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Turks and Caicos',2326,17,2201,4);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Monaco',2254,28,2057,9);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Cambodia',2233,10,1166,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Sao Tome and Principe',2212,34,2058,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Sint Maarten',2130,27,2073,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Liberia',2042,85,1899,2);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('St. Vincent Grenadines',1738,10,1587,2);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Saint Martin',1619,12,1399,7);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Isle of Man',1555,27,977,12);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Caribbean Netherlands',1300,10,885,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Antigua and Barbuda',1128,28,784,45);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Bermuda',1028,12,722,1);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Taiwan',1022,10,979,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Mauritius',920,10,629,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Bhutan',872,1,867,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('St. Barth',775,1,462,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Diamond Princess',712,13,699,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Faeroe Islands',661,1,660,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Tanzania',509,21,183,7);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Timor-Leste',491,null,169,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Cayman Islands',487,2,462,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Wallis and Futuna',374,4,44,4);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Brunei',206,3,188,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Dominica',161,null,153,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Grenada',155,1,152,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('British Virgin Islands',153,1,131,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('New Caledonia',121,null,58,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Fiji',67,2,64,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Falkland Islands',54,null,54,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Laos',49,null,45,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Macao',48,null,48,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Saint Kitts and Nevis',44,null,42,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Greenland',31,null,31,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Vatican City',27,null,15,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Saint Pierre Miquelon',24,null,24,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Anguilla',22,null,20,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Montserrat',20,1,19,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Solomon Islands',18,null,16,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Western Sahara',10,1,8,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('MS Zaandam',9,2,7,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Marshall Islands',4,null,4,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Samoa',3,null,2,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Vanuatu',3,null,1,null);
insert into covid(country_name, total_cases, deaths, recovered, serious) values('Micronesia',1,null,1,null);


-- updates daily
-- exec pkg_covid.add_new_cases(country_name, new_case, new_death, total_recovered, serious_case);
-- total_recovered | serious_case = null if unchanged from yesterdays record
exec pkg_covid.add_new_cases('Nepal', 55, 150, 3216351, 1654);
exec pkg_covid.add_new_cases('USA', 1255, 680, null, 500);


-- final select
-- select from view;
select * from vw_final;
