SETENV (ORACLE_HOME = "/u01/app/oracle/product/12.2.0.1/dbhome_1" )
SETENV (ORACLE_SID="HASBREP_1")
USERIDALIAS ogghasb901
TABLEEXCLUDE WMLM901HASB.SYS_EXPORT*;
TABLEEXCLUDE MSF901HASB.SYS_EXPORT*;
TABLEEXCLUDE RPT901HASB.SYS_EXPORT*;
TABLEEXCLUDE WMLM901HASB.TOAD_PLAN*;
TABLEEXCLUDE MSF901HASB.TOAD_PLAN*;
TABLEEXCLUDE RPT901HASB.TOAD_PLAN*;