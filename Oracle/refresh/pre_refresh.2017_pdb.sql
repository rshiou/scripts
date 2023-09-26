-- connect as the wmlm/msf user
-- DO NOT CONNECT AS SYS OR NFIDBA
set echo on

show user

pause
create or replace procedure manh_drop_objects
authid current_user
as
    v_stmt  varchar2(30000);
begin
for user_objects_rec in
(
    select object_type, object_name
    from user_objects
    where object_type in ('DATABASE LINK', 'PACKAGE', 'PROCEDURE',
        'FUNCTION', 'SEQUENCE', 'VIEW', 'MATERIALIZED VIEW','SYNONYM','TRIGGER')
        and object_name != 'MANH_DROP_OBJECTS' and object_name not like '%$%'
)
loop
    v_stmt := 'drop ' || user_objects_rec.object_type || ' '
        || user_objects_rec.object_name;
    execute immediate v_stmt;
end loop;

for user_tables_rec in
    (select table_name from user_tables where table_name not like '%$%' AND table_name NOT IN ('LICENSE','APPLICATION_CONFIGURATION'))
loop
    v_stmt := 'drop table ' || user_tables_rec.table_name
        || ' cascade constraints';
    execute immediate v_stmt;
end loop;

for user_types_rec in
    (select object_name from user_objects
     where object_type = 'TYPE')
loop
    v_stmt := 'drop type ' || user_types_rec.object_name;
    execute immediate v_stmt;
end loop;

end;
/

exec manh_drop_objects ;

drop procedure manh_drop_objects ;

purge recyclebin ;

