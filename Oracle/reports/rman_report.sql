SET PAGESIZE 1000
SET LINESIZE 150
SET FEEDBACK OFF
SET HEADING ON
SET TRIMSPOOL ON
COL con_id FORMAT 999
COL start_time FORMAT A20
COL end_time FORMAT A20
COL input_type FORMAT A10
COL status FORMAT A10
COL elapsed_hours FORMAT 999.99

SELECT con_id,
       TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
       TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
       input_type,
       status,
       round(elapsed_seconds / 3600, 2) AS elapsed_hours
FROM   V$RMAN_BACKUP_JOB_DETAILS
WHERE  start_time >= SYSDATE - 7
AND input_type <> 'ARCHIVELOG'
ORDER BY con_id, start_time;
exit;
