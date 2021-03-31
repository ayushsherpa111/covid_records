
create or replace type nig is object (
    name varchar2(20),
    age number
);

declare
    x nig := nig('',0);
begin
    x.name := 'hi';
    dbms_output.put_line(x.age);
    if x.age is null then
        dbms_output.put_line('bnlkn');
    end if;
end;


create or replace package test_pkg
as
    subtype xnum is number;
    type inner_rec is record (
        id xnum
    );
    function hello(u_name inner_rec) return inner_rec;
end;


create or replace package body test_pkg
as
   function hello(u_name inner_rec) return inner_rec
   as
    newOne inner_rec;
   begin
        newOne.id := v;
        dbms_output.put_line(u_name.id);
        return newOne;
   end hello;
end;

begin
    dbms_output.put_line(test_pkg.hello(test_pkg.inner_rec(1)).id);
end;

