create table COVID (
   country_name varchar2(50) primary key,
   total_cases number,
   deaths number,
   recovered number,
   serious number
);

create table newrecords (
    date_added date default current_date,
    country_name varchar2(50) references COVID(country_name),
    new_cases number check(new_cases >= 0),
    new_deaths number check(new_deaths >= 0),
    primary key(date_added, country_name)
);


