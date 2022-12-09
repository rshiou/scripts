select p2raw, p2/power(16,8) blocking_sid, p1 mutex_id, sid blocked_sid
from v$session
where event like 'cursor:%'
    and state='WAITING';
    
select requesting_session, blocking_session, sleep_timestamp, mutex_type
from v$mutex_sleep_history;

 select * 
from v$mutex_sleep;   

select count(*), sql_id,sql_child_number,session_state,blocking_session_status,event,wait_class 
from dba_hist_active_sess_history where snap_id between 18085 and 18086 and event like '%cursor: pin s%' 
group by sql_id,sql_child_number,session_state,blocking_session_status,event,wait_class;

select      user_process username,
       "Recursive Calls",
       "Opened Cursors",
       "Current Cursors"
    from  (
       select  nvl(ss.USERNAME,'ORACLE PROC')||'('||se.sid||') ' user_process,
                       sum(decode(NAME,'recursive calls',value)) "Recursive Calls",
                       sum(decode(NAME,'opened cursors cumulative',value)) "Opened Cursors",
                       sum(decode(NAME,'opened cursors current',value)) "Current Cursors"
      from    v$session ss,
                v$sesstat se,
                 v$statname sn
      where   se.STATISTIC# = sn.STATISTIC#
      and     (NAME  like '%opened cursors current%'
      or       NAME  like '%recursive calls%'
      or       NAME  like '%opened cursors cumulative%')
      and     se.SID = ss.SID
      and     ss.USERNAME is not null
      group   by nvl(ss.USERNAME,'ORACLE PROC')||'('||se.SID||') '
   )
   orasnap_user_cursors
   order      by USER_PROCESS,"Recursive Calls";