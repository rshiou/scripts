SHOW USER ;

SELECT COUNT(*)
FROM   ucl_user
WHERE  ispasswordmanagedinternally <> '1' ;
set serveroutput on

DECLARE
 v_count integer;
BEGIN

SELECT COUNT(*)
INTO   v_count
FROM   ucl_user
WHERE  ispasswordmanagedinternally <> '1' ;

IF v_count > 0 THEN
  dbms_output.put_line('Total count is: '|| v_count);
  dbms_output.put_line('Run update to ucl_user');
  EXECUTE IMMEDIATE 'update ucl_user set ispasswordmanagedinternally = ''1'' where ispasswordmanagedinternally <> ''1''' ;
END IF;

END;
/

SELECT COUNT(*)
FROM   ucl_user
WHERE  ispasswordmanagedinternally <> '1' ;


