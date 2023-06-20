---------------------------------------------------------------------------------------
-- Instructions.....: 1. Connect to your WMS database from command prompt
--                    2. Execute command: @NFI_WMS_Missed_Triggers.sql 
----------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------
--Script Name: NFI_WMS_Missed_Triggers.sql
-----------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------
show user;
pause;
SET SCAN OFF;
SET DEFINE OFF;
SET ECHO ON;

spool NFI_WMS_Missed_Triggers.log

create or replace TRIGGER COMB_LANE_BIU_TR
before insert or update
ON COMB_LANE
REFERENCING OLD AS OLD NEW AS NEW
FOR EACH ROW
DECLARE
BEGIN
:new.LANE_UNIQUE_ID := :new.LANE_ID * SIGN (:new.LANE_STATUS);
:new.O_SEARCH_LOCATION :=
  LANE_LOCATION_PKG.FNGETLOCATIONSTRING (:new.O_LOC_TYPE,       --aLocType
                                         :new.O_FACILITY_ID, --aFacilityId
                                         :new.O_CITY,              --aCity
                                         :new.O_COUNTY,          --aCounty
                                         :new.O_STATE_PROV,   --aStateProv
                                         :new.O_POSTAL_CODE, --aPostalCode
                                         :new.O_COUNTRY_CODE, --aCountryCode
                                         :new.O_ZONE_ID          --aZoneId
                                                       );
:new.D_SEARCH_LOCATION :=
  LANE_LOCATION_PKG.FNGETLOCATIONSTRING (:new.D_LOC_TYPE,       --aLocType
                                         :new.D_FACILITY_ID, --aFacilityId
                                         :new.D_CITY,              --aCity
                                         :new.D_COUNTY,          --aCounty
                                         :new.D_STATE_PROV,   --aStateProv
                                         :new.D_POSTAL_CODE, --aPostalCode
                                         :new.D_COUNTRY_CODE, --aCountryCode
                                         :new.D_ZONE_ID          --aZoneId
                                                       );
end COMB_LANE_BIU_TR;
/
create or replace TRIGGER SRVLVL_B_U_TR_1
 BEFORE UPDATE
 ON SERVICE_LEVEL
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
DECLARE
 time_now   DATE;
BEGIN
 time_now := SYSDATE;
 :new.LAST_UPDATED_DTTM := time_now;
END;
/

create or replace TRIGGER TR_LABOR_ACTIVITY
 BEFORE INSERT
 ON LABOR_ACTIVITY
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
DECLARE
 ID   NUMBER (9);
BEGIN
 IF :NEW.LABOR_ACTIVITY_ID IS NULL
 THEN
  SELECT LABOR_ACTIVITY_ID_SEQ.NEXTVAL
    INTO :NEW.LABOR_ACTIVITY_ID
    FROM DUAL;
 END IF;
END;
/

create or replace TRIGGER RATING_LANE_DTL_RATE_BIU_TR
   BEFORE UPDATE
   ON "RATING_LANE_DTL_RATE"
   REFERENCING OLD AS OLD NEW AS NEW
   FOR EACH ROW
DECLARE
BEGIN
   UPDATE COMB_LANE_DTL
      SET LAST_UPDATED_DTTM = SYSDATE
    WHERE     TC_COMPANY_ID = :new.TC_COMPANY_ID
          AND LANE_ID = :new.LANE_ID
          AND LANE_DTL_SEQ = :new.RATING_LANE_DTL_SEQ;
END RATING_LANE_DTL_RATE_BIU_TR;
/

create or replace TRIGGER FAC_CONTACT_B_I_1
 BEFORE INSERT
 ON FACILITY_CONTACT
 REFERENCING NEW AS N
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
BEGIN
 SELECT NVL (MAX (facility_contact_id), 0) + 1
 INTO :n.facility_contact_id
 FROM FACILITY_CONTACT
WHERE facility_id = :n.facility_id;
END;
/

create or replace TRIGGER DOCK_DOOR_REF_1_TRIG
AFTER UPDATE ON DOCK_DOOR
FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
BEGIN
IF (:NEW.MARK_FOR_DELETION = 1 AND :OLD.MARK_FOR_DELETION=0) THEN
  BEGIN
    DELETE FROM DOCK_DOOR_REF DDR WHERE DDR.DOCK_DOOR_ID = :NEW.DOCK_DOOR_ID ;
  END;
END IF;
IF (:NEW.MARK_FOR_DELETION =0 AND :OLD.MARK_FOR_DELETION=1) THEN
  BEGIN
    INSERT INTO DOCK_DOOR_REF (DOCK_DOOR_ID) VALUES (:NEW.DOCK_DOOR_ID);
  END;
END IF;
END DOCK_DOOR_REF_1_TRIG;
/

create or replace TRIGGER DOCK_DOOR_REF_2_TRIG
AFTER INSERT ON DOCK_DOOR
FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
BEGIN
INSERT INTO DOCK_DOOR_REF (DOCK_DOOR_ID) VALUES (:NEW.DOCK_DOOR_ID) ;
END DOCK_DOOR_REF_2_TRIG;
/

create or replace TRIGGER SYS_CODE_PARM_AIU_INTG
    AFTER INSERT OR UPDATE
    ON SYS_CODE_PARM
    REFERENCING NEW AS new OLD AS OLD
    FOR EACH ROW
DECLARE
    record_exists             NUMBER (1);
    order_streaming_enabled   NUMBER (1);
BEGIN
    SELECT CASE
               WHEN LOWER (TO_CHAR (SUBSTR (VALUE, 0, 4))) = 'true' THEN 1
               ELSE 0
           END
      INTO order_streaming_enabled
      FROM APPLICATION_CONFIGURATION
     WHERE KEY = 'orderstreaming.enabled';

    IF INSERTING
    THEN
        SELECT CASE
                   WHEN EXISTS
                            (SELECT 1
                               FROM BASE_DATA_DELTA
                              WHERE     OBJECT_TYPE = 'SYSTEM_CODE'
                                    AND OBJECT_ID =
                                               :new.REC_TYPE
                                            || ':'
                                            || :new.CODE_TYPE)
                   THEN
                       1
                   ELSE
                       0
               END
          INTO record_exists
          FROM DUAL;

        IF (record_exists = 0 AND order_streaming_enabled = 1)
        THEN
            INSERT INTO base_data_delta (object_type,
                                         object_id,
                                         company_id,
                                         action_type,
                                         created_dttm)
                 VALUES ('SYSTEM_CODE',
                         :new.REC_TYPE || ':' || :new.CODE_TYPE,
                         NULL,
                         'CREATE',
                         CURRENT_TIMESTAMP);
        END IF;
    ELSIF UPDATING
    THEN
        SELECT CASE
                   WHEN EXISTS
                            (SELECT 1
                               FROM BASE_DATA_DELTA
                              WHERE     OBJECT_TYPE = 'SYSTEM_CODE'
                                    AND OBJECT_ID =
                                               :old.REC_TYPE
                                            || ':'
                                            || :old.CODE_TYPE)
                   THEN
                       1
                   ELSE
                       0
               END
          INTO record_exists
          FROM DUAL;

        IF (record_exists = 0 AND order_streaming_enabled = 1)
        THEN
            INSERT INTO base_data_delta (object_type,
                                         object_id,
                                         company_id,
                                         action_type,
                                         created_dttm)
                 VALUES ('SYSTEM_CODE',
                         :old.REC_TYPE || ':' || :old.CODE_TYPE,
                         NULL,
                         'UPDATE',
                         CURRENT_TIMESTAMP);
        END IF;
    END IF;
END;
/

create or replace TRIGGER BP_AFT_DLT
 AFTER DELETE
 ON BUSINESS_PARTNER
 REFERENCING OLD AS O
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
BEGIN
 DELETE_VM (:O.tc_company_id);
END;
/

create or replace TRIGGER BP_AFT_UPD
 AFTER UPDATE OF address_1, address_2, city, country_code, last_updated_dttm, state_prov, tel_nbr, last_updated_source, description, postal_code
 ON BUSINESS_PARTNER
 REFERENCING OLD AS old NEW AS new
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
BEGIN
 IF (:new.address_1 <> :old.address_1)
 THEN
  UPDATE vendor_master
     SET addr_1 = (SELECT :new.address_1 FROM DUAL)
   WHERE vendor_master.cd_master_id = :old.tc_company_id
         AND vendor_master.vendor_id = :old.business_partner_id;
 END IF;
 IF (:new.address_2 <> :old.address_2)
 THEN
  UPDATE vendor_master
     SET addr_2 = (SELECT :new.address_2 FROM DUAL)
   WHERE vendor_master.cd_master_id = :old.tc_company_id
         AND vendor_master.vendor_id = :old.business_partner_id;
 END IF;
 IF (:new.city <> :old.city)
 THEN
  UPDATE vendor_master
     SET city = (SELECT :new.city FROM DUAL)
   WHERE vendor_master.cd_master_id = :old.tc_company_id
         AND vendor_master.vendor_id = :old.business_partner_id;
 END IF;
 IF (:new.country_code <> :old.country_code)
 THEN
  UPDATE vendor_master
     SET cntry = (SELECT :new.country_code FROM DUAL)
   WHERE vendor_master.cd_master_id = :old.tc_company_id
         AND vendor_master.vendor_id = :old.business_partner_id;
 END IF;
 IF (:new.last_updated_dttm <> :old.last_updated_dttm)
 THEN
  UPDATE vendor_master
     SET mod_date_time = (SELECT :new.last_updated_dttm FROM DUAL)
   WHERE vendor_master.cd_master_id = :old.tc_company_id
         AND vendor_master.vendor_id = :old.business_partner_id;
 END IF;
 IF (:new.state_prov <> :old.state_prov)
 THEN
  UPDATE vendor_master
     SET state = (SELECT :new.state_prov FROM DUAL)
   WHERE vendor_master.cd_master_id = :old.tc_company_id
         AND vendor_master.vendor_id = :old.business_partner_id;
 END IF;
 IF (:new.tel_nbr <> :old.tel_nbr)
 THEN
  UPDATE vendor_master
     SET tel_nbr = (SELECT :new.tel_nbr FROM DUAL)
   WHERE vendor_master.cd_master_id = :old.tc_company_id
         AND vendor_master.vendor_id = :old.business_partner_id;
 END IF;
 IF (:new.last_updated_source <> :old.last_updated_source)
 THEN
  UPDATE vendor_master
     SET user_id = (SELECT :new.last_updated_source FROM DUAL)
   WHERE vendor_master.cd_master_id = :old.tc_company_id
         AND vendor_master.vendor_id = :old.business_partner_id;
 END IF;
 IF (:new.description <> :old.description)
 THEN
  UPDATE vendor_master
     SET vendor_name = (SELECT :new.description FROM DUAL)
   WHERE vendor_master.cd_master_id = :old.tc_company_id
         AND vendor_master.vendor_id = :old.business_partner_id;
 END IF;
 IF (:new.postal_code <> :old.postal_code)
 THEN
  UPDATE vendor_master
     SET zip = (SELECT :new.postal_code FROM DUAL)
   WHERE vendor_master.cd_master_id = :old.tc_company_id
         AND vendor_master.vendor_id = :old.business_partner_id;
 END IF;
END;
/

create or replace TRIGGER BP_AFT_INSRT
 AFTER INSERT
 ON BUSINESS_PARTNER
 REFERENCING NEW AS NEW
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
BEGIN
 INSRT_VM (:NEW.business_partner_ID,
         :NEW.description,
         SUBSTR (:NEW.ADDRESS_1, 1, 75),
         SUBSTR (:NEW.ADDRESS_2, 1, 75),
         :NEW.city,
         :NEW.STATE_PROV,
         :NEW.postal_code,
         :NEW.country_code,
         :NEW.tel_nbr,
         :NEW.created_dttm,
         :NEW.created_dttm,
         :NEW.created_source,
         :NEW.tc_company_id);
END;
/

create or replace TRIGGER WHSE_SYS_CODE_AIU_INTG
    AFTER UPDATE
    ON WHSE_SYS_CODE
    REFERENCING NEW AS new OLD AS OLD
    FOR EACH ROW
DECLARE
    record_exists             NUMBER (1);
    order_streaming_enabled   NUMBER (1);
BEGIN
    SELECT CASE
               WHEN EXISTS
                        (SELECT 1
                           FROM BASE_DATA_DELTA
                          WHERE     OBJECT_TYPE = 'SYSTEM_CODE'
                                AND OBJECT_ID =
                                           :old.REC_TYPE
                                        || ':'
                                        || :old.CODE_TYPE
                                        || ':'
                                        || :old.WHSE
                                        || ':'
                                        || :old.CODE_ID)
               THEN
                   1
               ELSE
                   0
           END
      INTO record_exists
      FROM DUAL;

    SELECT CASE
               WHEN LOWER (TO_CHAR (SUBSTR (VALUE, 0, 4))) = 'true' THEN 1
               ELSE 0
           END
      INTO order_streaming_enabled
      FROM APPLICATION_CONFIGURATION
     WHERE KEY = 'orderstreaming.enabled';

    IF (record_exists = 0 AND order_streaming_enabled = 1)
    THEN
        INSERT INTO base_data_delta (object_type,
                                     object_id,
                                     company_id,
                                     action_type,
                                     created_dttm)
                 VALUES (
                            'SYSTEM_CODE',
                               :old.REC_TYPE
                            || ':'
                            || :old.CODE_TYPE
                            || ':'
                            || :old.WHSE
                            || ':'
                            || :old.CODE_ID,
                            NULL,
                            'UPDATE',
                            CURRENT_TIMESTAMP);
    END IF;
END;
/

create or replace TRIGGER CMPNY_AFT_INS
 AFTER INSERT
 ON COMPANY
 REFERENCING NEW AS N
 FOR EACH ROW
BEGIN
 INSERT INTO CD_MASTER (CD_MASTER_ID,
                      company_name,
                      CREATE_DATE_TIME,
                      MOD_DATE_TIME,
                      USER_ID)
    VALUES (:N.COMPANY_ID,
            :N.COMPANY_NAME,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM');
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'AUTO_CREATE_BATCH_FLAG',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'BATCH_CTRL_FLAG',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'BATCH_ROLE_ID',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'CASE_LOCK_CODE_EXP_REC',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'CASE_LOCK_CODE_HELD',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'COLOR_MASK',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'COLOR_OFFSET',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'COLOR_SEPTR',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'COLOR_SFX_MASK',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'COLOR_SFX_OFFSET',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'COLOR_SFX_SEPTR',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'DFLT_BATCH_STAT_CODE',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'DSP_ITEM_DESC_FLAG',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'LOCK_CODE_INVALID',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'PICK_LOCK_CODE_EXP_REC',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'PICK_LOCK_CODE_HELD',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'PROC_WHSE_XFER',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'QUAL_MASK',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'QUAL_OFFSET',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'QUAL_SEPTR',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'RECV_BATCH',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SEASON_MASK',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SEASON_OFFSET',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SEASON_SEPTR',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SEASON_YR_MASK',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SEASON_YR_OFFSET',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SEASON_YR_SEPTR',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SEC_DIM_MASK',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SEC_DIM_OFFSET',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SEC_DIM_SEPTR',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SIZE_DESC_MASK',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SIZE_DESC_OFFSET',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SIZE_DESC_SEPTR',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SKU_MASK',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'SKU_OFFSET_MASK',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'STYLE_MASK',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'STYLE_OFFSET',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'STYLE_SEPTR',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'STYLE_SFX_MASK',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'STYLE_SFX_OFFSET',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'STYLE_SFX_SEPTR',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
 INSERT INTO CD_MASTER_DTL (CD_MASTER_ID,
                          COLUMN_NAME,
                          COLUMN_VALUE,
                          CREATE_DATE_TIME,
                          MOD_DATE_TIME,
                          USER_ID,
                          CD_MASTER_DTL_ID)
    VALUES (:N.COMPANY_ID,
            'UCC_EAN_CO_PFX',
            NULL,
            :N.CREATED_DTTM,
            :N.CREATED_DTTM,
            'SYSTEM',
            CD_MASTER_DTL_ID_SEQ.NEXTVAL);
END;
/

create or replace TRIGGER COMPANY_AI
 AFTER INSERT
 ON COMPANY
 REFERENCING NEW AS NEW
 FOR EACH ROW
DECLARE
 V_DL_ID     NUMBER;
 V_COUNT     NUMBER;
 VGENID      NUMBER;
 V_SHIP_ID   NUMBER;
BEGIN
 SELECT COMPANY_TYPE_ID
 INTO V_SHIP_ID
 FROM COMPANY_TYPE
WHERE LOWER (DESCRIPTION) = LOWER ('Shipper');
 IF (V_SHIP_ID = :NEW.COMPANY_TYPE_ID)
 THEN
  INSERT INTO RS_CONFIG (RS_CONFIG_ID,
                         TC_COMPANY_ID,
                         RS_CONFIG_NAME,
                         IS_VALID,
                         IS_ACTIVE,
                         CREATED_SOURCE_TYPE,
                         CREATED_SOURCE,
                         LAST_UPDATED_SOURCE_TYPE,
                         LAST_UPDATED_SOURCE)
       VALUES (SEQ_RS_CONFIG_ID.NEXTVAL,
               :NEW.COMPANY_ID,
               'Default',
               1,
               1,
               2,
               'LDAP',
               2,
               'LDAP');
  INSERT INTO PERFORMANCE_FACTOR (PERFORMANCE_FACTOR_ID,
                                  TC_COMPANY_ID,
                                  PERFORMANCE_FACTOR_NAME,
                                  PF_TYPE,
                                  DESCRIPTION,
                                  DEFAULT_VALUE,
                                  IS_USE_FLAG,
                                  CREATED_SOURCE_TYPE,
                                  CREATED_SOURCE,
                                  LAST_UPDATED_SOURCE_TYPE,
                                  LAST_UPDATED_SOURCE)
       VALUES (SEQ_PERFORMANCE_FACTOR_ID.NEXTVAL,
               :NEW.COMPANY_ID,
               'ON TIME',
               3,
               'On Time',
               0,
               0,
               2,
               'LDAP',
               2,
               'LDAP');
  INSERT INTO PERFORMANCE_FACTOR (PERFORMANCE_FACTOR_ID,
                                  TC_COMPANY_ID,
                                  PERFORMANCE_FACTOR_NAME,
                                  PF_TYPE,
                                  DESCRIPTION,
                                  DEFAULT_VALUE,
                                  IS_USE_FLAG,
                                  CREATED_SOURCE_TYPE,
                                  CREATED_SOURCE,
                                  LAST_UPDATED_SOURCE_TYPE,
                                  LAST_UPDATED_SOURCE)
       VALUES (SEQ_PERFORMANCE_FACTOR_ID.NEXTVAL,
               :NEW.COMPANY_ID,
               'ACCEPT RATIO',
               2,
               'Accept Rat',
               0,
               0,
               2,
               'LDAP',
               2,
               'LDAP');
  INSERT INTO RS_AREA (TC_COMPANY_ID,
                       RS_AREA_ID,
                       RS_AREA,
                       DESCRIPTION,
                       COMMENTS,
                       CREATED_SOURCE,
                       LAST_UPDATED_SOURCE)
       VALUES (
                 :NEW.COMPANY_ID,
                 RS_AREA_ID_SEQ.NEXTVAL,
                 'RSArealess',
                 'RSArealess',
                 'For Internal Use Only.  Used for shipments that can not be assigned to a RSArea.',
                 '0',
                 '0');
  INSERT INTO ILM_REASON_CODES (REASON_CODE_ID,
                                TYPE,
                                TC_COMPANY_ID,
                                DESCRIPTION)
       VALUES (17,
               'TRLR',
               :NEW.COMPANY_ID,
               'Yard Audit Lock');
  INSERT INTO ILM_REASON_CODES (REASON_CODE_ID,
                                TYPE,
                                TC_COMPANY_ID,
                                DESCRIPTION)
       VALUES (12,
               'TASK',
               :NEW.COMPANY_ID,
               'A trailer already in location');
  INSERT INTO CLAIM_ACTION_CODE (CLAIM_ACTION_CODE,
                                 CLAIM_ACTION_TYPE,
                                 TC_COMPANY_ID,
                                 DESCRIPTION)
     SELECT CLAIM_ACTION_CODE,
            CLAIM_ACTION_TYPE,
            :NEW.COMPANY_ID,
            DESCRIPTION
       FROM CLAIM_SYSTEM_ACTION_CODE SA
      WHERE NOT EXISTS
                   (SELECT 1
                      FROM CLAIM_ACTION_CODE A
                     WHERE A.CLAIM_ACTION_CODE = SA.CLAIM_ACTION_CODE
                           AND A.TC_COMPANY_ID = :NEW.COMPANY_ID);
 END IF;
 INSERT INTO DISTRIBUTION_LIST (TC_COMPANY_ID,
                              DESCRIPTION,
                              IS_PREFERRED_LIST,
                              TC_CONTACT_ID)
    VALUES (:NEW.COMPANY_ID,
            'All Company Carriers',
            1,
            0);
 INSERT INTO DISTRIBUTION_LIST (TC_COMPANY_ID,
                              DESCRIPTION,
                              IS_PREFERRED_LIST,
                              TC_CONTACT_ID)
    VALUES (:NEW.COMPANY_ID,
            'All Lane Carriers',
            2,
            0);
 UPDATE RS_CONFIG
  SET RS_CONFIG_RANK = NULL
WHERE TC_COMPANY_ID = :NEW.COMPANY_ID;
 INSERT INTO INVOICE_RESP_CODE
    VALUES (SEQ_INVOICE_RESP_CODE_ID.NEXTVAL,
            :NEW.COMPANY_ID,
            'ADTR',
            'FAP Auditor',
            0,
            0);
 INSERT INTO INVOICE_RESP_CODE
    VALUES (SEQ_INVOICE_RESP_CODE_ID.NEXTVAL,
            :NEW.COMPANY_ID,
            'CARR',
            'Carrier',
            0,
            1);
 INSERT INTO INVOICE_RESP_CODE
    VALUES (SEQ_INVOICE_RESP_CODE_ID.NEXTVAL,
            :NEW.COMPANY_ID,
            'CRLS',
            'Carrier Relations',
            0,
            0);
 INSERT INTO INVOICE_RESP_CODE
    VALUES (SEQ_INVOICE_RESP_CODE_ID.NEXTVAL,
            :NEW.COMPANY_ID,
            'MNGR',
            'FAP Manager',
            0,
            0);
 INSERT INTO INVOICE_RESP_CODE
    VALUES (SEQ_INVOICE_RESP_CODE_ID.NEXTVAL,
            :NEW.COMPANY_ID,
            'DTRC',
            'Detention Resolution Center',
            0,
            0);
 INSERT INTO PRICE_TYPE_CBO (PRICE_TYPE_ID,
                           COMPANY_ID,
                           AUDIT_CREATED_SOURCE,
                           AUDIT_LAST_UPDATED_SOURCE,
                           OWNED_BY,
                           AUDIT_LAST_UPDATED_DTTM,
                           VERSION,
                           AUDIT_CREATED_DTTM,
                           NAME,
                           DESCRIPTION,
                           AUDIT_LAST_UPDATED_SOURCE_TYPE,
                           AUDIT_CREATED_SOURCE_TYPE,
                           AUDIT_TRANSACTION,
                           AUDIT_PARTY_ID,
                           MARK_FOR_DELETION)
    VALUES (PRICE_TYPE_ID_SEQ.NEXTVAL,
            :NEW.COMPANY_ID,
            '1',
            '1',
            11,
            SYSDATE,
            1,
            SYSDATE,
            'REGULAR',
            '11',
            1,
            11,
            '11',
            11,
            0);
 INSERT INTO PRICE_TYPE_CBO (PRICE_TYPE_ID,
                           COMPANY_ID,
                           AUDIT_CREATED_SOURCE,
                           AUDIT_LAST_UPDATED_SOURCE,
                           OWNED_BY,
                           AUDIT_LAST_UPDATED_DTTM,
                           VERSION,
                           AUDIT_CREATED_DTTM,
                           NAME,
                           DESCRIPTION,
                           AUDIT_LAST_UPDATED_SOURCE_TYPE,
                           AUDIT_CREATED_SOURCE_TYPE,
                           AUDIT_TRANSACTION,
                           AUDIT_PARTY_ID,
                           MARK_FOR_DELETION)
    VALUES (PRICE_TYPE_ID_SEQ.NEXTVAL,
            :NEW.COMPANY_ID,
            '1',
            '1',
            11,
            SYSDATE,
            1,
            SYSDATE,
            'PROMOTIONAL',
            '12',
            1,
            11,
            '11',
            11,
            0);
 IF (:NEW.PARENT_COMPANY_ID = -1)
 THEN
  INSERT INTO OM_SCHED_EVENT (EVENT_ID,
                              SCHEDULED_DTTM,
                              EVENT_OBJECTS,
                              EVENT_TIMESTAMP,
                              OM_CATEGORY,
                              EVENT_TYPE,
                              EVENT_EXP_DATE,
                              EVENT_CNT,
                              EVENT_FREQ_IN_DAYS,
                              EVENT_FREQ_PER_DAY,
                              EXECUTED_DTTM,
                              IS_EXECUTED,
                              EVENT_FREQ_IN_DAY_OF_MONTH)
       VALUES (
                 SEQ_EVENT_ID.NEXTVAL,
                 SYSDATE,
                 '{eventProcessorClass=com.manh.baseservices.util.defaultbasedata.AutoCreateBaseDataScheduler, shipperPK='
                 || TO_CHAR (:NEW.COMPANY_ID)
                 || '}',
                 SYSDATE,
                 null,
                 0,
                 NULL,
                 0,
                 0,
                 0,
                 NULL,
                 0,
                 0);
 END IF;
END;
/

create or replace TRIGGER CMPNY_BFR_DEL
 BEFORE DELETE
 ON COMPANY
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
BEGIN
        DELETE FROM DFLT_FACILITY WHERE COMPANY_ID = :OLD.COMPANY_ID;
        DELETE FROM REASON_CODE WHERE COMPANY_ID = :OLD.COMPANY_ID AND REASON_CODE = 'CAN';
        DELETE FROM REASON_CODE WHERE COMPANY_ID = :OLD.COMPANY_ID AND REASON_CODE = 'OVR';

        DELETE FROM ROLE_APP_MOD_PERM WHERE ROLE_ID IN (SELECT ROLE_ID FROM ROLE WHERE COMPANY_ID = :OLD.COMPANY_ID);
        DELETE FROM ROLE WHERE COMPANY_ID = :OLD.COMPANY_ID;

        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'AUTO_CREATE_BATCH_FLAG';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'BATCH_CTRL_FLAG';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'BATCH_ROLE_ID';

        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'CASE_LOCK_CODE_EXP_REC';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'CASE_LOCK_CODE_HELD';

        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'COLOR_MASK';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'COLOR_OFFSET';

        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'COLOR_SEPTR';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'COLOR_SFX_MASK';

        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'COLOR_SFX_OFFSET';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'COLOR_SFX_SEPTR';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'DFLT_BATCH_STAT_CODE';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'DSP_ITEM_DESC_FLAG';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'LOCK_CODE_INVALID';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'PICK_LOCK_CODE_EXP_REC';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'PICK_LOCK_CODE_HELD';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'PROC_WHSE_XFER';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'QUAL_MASK';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'QUAL_OFFSET';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'QUAL_SEPTR';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'RECV_BATCH';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SEASON_MASK';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SEASON_OFFSET';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SEASON_SEPTR';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SEASON_YR_MASK';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SEASON_YR_OFFSET';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SEASON_YR_SEPTR';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SEC_DIM_MASK';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SEC_DIM_OFFSET';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SEC_DIM_SEPTR';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SIZE_DESC_MASK';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SIZE_DESC_OFFSET';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SIZE_DESC_SEPTR';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SKU_MASK';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'SKU_OFFSET_MASK';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'STYLE_MASK';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'STYLE_OFFSET';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'STYLE_SEPTR';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'STYLE_SFX_MASK';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'STYLE_SFX_OFFSET';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'STYLE_SFX_SEPTR';
        DELETE FROM CD_MASTER_DTL where CD_MASTER_ID = :OLD.COMPANY_ID and COLUMN_NAME = 'UCC_EAN_CO_PFX';
        DELETE FROM CD_MASTER where CD_MASTER_ID = :OLD.COMPANY_ID;
		DELETE FROM RS_CONFIG WHERE TC_COMPANY_ID = :OLD.COMPANY_ID;
  DELETE FROM PERFORMANCE_FACTOR WHERE TC_COMPANY_ID =:OLD.COMPANY_ID AND PERFORMANCE_FACTOR_NAME = 'ON TIME';
  DELETE FROM PERFORMANCE_FACTOR WHERE TC_COMPANY_ID =:OLD.COMPANY_ID AND PERFORMANCE_FACTOR_NAME = 'ACCEPT RATIO';
  DELETE FROM RS_AREA where TC_COMPANY_ID =:OLD.COMPANY_ID;
  DELETE FROM ILM_REASON_CODES WHERE TYPE = 'TRLR' AND TC_COMPANY_ID = :OLD.COMPANY_ID;
  DELETE FROM ILM_REASON_CODES WHERE TYPE = 'TASK' AND TC_COMPANY_ID = :OLD.COMPANY_ID;
  DELETE FROM CLAIM_ACTION_CODE WHERE TC_COMPANY_ID = :OLD.COMPANY_ID;
  DELETE FROM DISTRIBUTION_LIST WHERE TC_COMPANY_ID = :OLD.COMPANY_ID AND DESCRIPTION =  'All Company Carriers';
  DELETE FROM DISTRIBUTION_LIST WHERE TC_COMPANY_ID = :OLD.COMPANY_ID AND DESCRIPTION =  'All Lane Carriers';
  DELETE FROM INVOICE_RESP_CODE WHERE TC_COMPANY_ID = :OLD.COMPANY_ID AND DESCRIPTION_SHORT = 'CARR';
  DELETE FROM INVOICE_RESP_CODE WHERE TC_COMPANY_ID = :OLD.COMPANY_ID AND DESCRIPTION_SHORT = 'CRLS';
  DELETE FROM INVOICE_RESP_CODE WHERE TC_COMPANY_ID = :OLD.COMPANY_ID AND DESCRIPTION_SHORT = 'MNGR';
  DELETE FROM INVOICE_RESP_CODE WHERE TC_COMPANY_ID = :OLD.COMPANY_ID AND DESCRIPTION_SHORT = 'DTRC';
  DELETE FROM PRICE_TYPE_CBO WHERE COMPANY_ID = :OLD.COMPANY_ID AND NAME = 'REGULAR';
  DELETE FROM PRICE_TYPE_CBO WHERE COMPANY_ID = :OLD.COMPANY_ID AND NAME = 'PROMOTIONAL';
  DELETE FROM OM_SCHED_EVENT WHERE EVENT_OBJECTS LIKE '{eventProcessorClass=com.manh.baseservices.util.defaultbasedata.AutoCreateBaseDataScheduler, shipperPK=' || TO_CHAR (:OLD.COMPANY_ID) || '}';
END;
/

create or replace TRIGGER LANE_ACCESSORIAL_B_I_TR_1
 BEFORE INSERT
 ON LANE_ACCESSORIAL
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
DECLARE
BEGIN
 SELECT LANE_ACCESSORIAL_ID_SEQ.NEXTVAL
 INTO :new.LANE_ACCESSORIAL_ID
 FROM DUAL;
END LANE_ACCESSORIAL_B_I_TR_1;
/

create or replace TRIGGER LANE_ACCESSORIAL_B_DEL_TR_1
 BEFORE DELETE
 ON LANE_ACCESSORIAL
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
BEGIN
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'ACCESSORIAL_CODE';
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'RATE';
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'Payee';
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'Min Rate';
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'CURRENCY_CODE';
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'Min Qty';
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'Max Qty';
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'Is Auto Approve';
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'IS_SHIPMENT_ACCESSORIAL';
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'EFFECTIVE_DT';
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'EXPIRATION_DT';
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'INCOTERM';
 DELETE FROM RATING_EVENT WHERE TC_COMPANY_ID = :OLD.TC_COMPANY_ID AND FIELD_NAME = 'LAST UPDATED DATETIME';
END;
/

create or replace TRIGGER LANE_ACCESSORIAL_A_IU_TR_1
 AFTER INSERT OR UPDATE
 ON LANE_ACCESSORIAL
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
DECLARE
 vOldValue             RATING_EVENT.OLD_VALUE%TYPE;
 vNewValue             RATING_EVENT.NEW_VALUE%TYPE;
 OldIncotermName       INCOTERM.INCOTERM_NAME%TYPE;
 NewIncotermName       INCOTERM.INCOTERM_NAME%TYPE;
 vChgFlag              NUMBER (1);
 vOldAccessorialCode   VARCHAR2 (1000);
 vNewAccessorialCode   VARCHAR2 (1000);
BEGIN
 vChgFlag := 0;
 -- Accessorial Id
 IF (   (:old.ACCESSORIAL_ID != :new.ACCESSORIAL_ID)
   OR (:old.ACCESSORIAL_ID IS NULL AND :new.ACCESSORIAL_ID IS NOT NULL)
   OR (:new.ACCESSORIAL_ID IS NULL AND :old.ACCESSORIAL_ID IS NOT NULL))
 THEN
  IF (:old.ACCESSORIAL_ID IS NOT NULL)
  THEN
  BEGIN
     SELECT accessorial_code
       INTO vOldAccessorialCode
       FROM accessorial_code
      WHERE accessorial_id = :old.ACCESSORIAL_ID;
		 exception when no_data_found then vChgFlag := 0;
   END;
  ELSE
     vOldAccessorialCode := :old.ACCESSORIAL_ID;
  END IF;
  IF (:new.ACCESSORIAL_ID IS NOT NULL)
  THEN
     SELECT accessorial_code
       INTO vNewAccessorialCode
       FROM accessorial_code
      WHERE accessorial_id = :new.ACCESSORIAL_ID;
  ELSE
     vNewAccessorialCode := :new.ACCESSORIAL_ID;
  END IF;
  INS_RATING_EVENT (:new.LANE_ID,
                    :new.RATING_LANE_DTL_SEQ,
                    NULL,                                -- no RLD_RATE_ID
                    :new.TC_COMPANY_ID,
                    NULL,                                  -- no CHANGE_ID
                    'ACCESSORIAL_CODE',
                    vOldAccessorialCode,
                    vNewAccessorialCode,
                    :new.COMMENTS,
                    :new.LAST_UPDATED_SRC_TYPE,
                    :new.LAST_UPDATED_SRC,
                    NULL,                              -- no AUTH_SRC_TYPE
                    NULL,                                   -- no AUTH_SRC
                    :new.LAST_UPDATED_DTTM,
                    :new.LANE_ACCESSORIAL_ID,
                    :new.REASON_ID);
  vChgFlag := 1;
 END IF;
 -- Rate
 IF (   (:old.RATE != :new.RATE)
   OR (:old.RATE IS NULL AND :new.RATE IS NOT NULL)
   OR (:new.RATE IS NULL AND :old.RATE IS NOT NULL))
 THEN
  INS_RATING_EVENT (:new.LANE_ID,
                    :new.RATING_LANE_DTL_SEQ,
                    NULL,                                -- no RLD_RATE_ID
                    :new.TC_COMPANY_ID,
                    NULL,                                  -- no CHANGE_ID
                    'RATE',
                    :old.RATE,
                    :new.RATE,
                    :new.COMMENTS,
                    :new.LAST_UPDATED_SRC_TYPE,
                    :new.LAST_UPDATED_SRC,
                    NULL,                              -- no AUTH_SRC_TYPE
                    NULL,                                   -- no AUTH_SRC
                    :new.LAST_UPDATED_DTTM,
                    :new.LANE_ACCESSORIAL_ID,
                    :new.REASON_ID);
  vChgFlag := 1;
 END IF;
 -- payee_carrier_code
 IF ( (:old.PAYEE_CARRIER_ID != :new.PAYEE_CARRIER_ID)
   OR (:old.PAYEE_CARRIER_ID IS NULL
       AND :new.PAYEE_CARRIER_ID IS NOT NULL)
   OR (:new.PAYEE_CARRIER_ID IS NULL
       AND :old.PAYEE_CARRIER_ID IS NOT NULL))
 THEN
  INS_RATING_EVENT (:new.LANE_ID,
                    :new.RATING_LANE_DTL_SEQ,
                    NULL,                                -- no RLD_RATE_ID
                    :new.TC_COMPANY_ID,
                    NULL,                                  -- no CHANGE_ID
                    'Payee',
                    :old.PAYEE_CARRIER_ID,
                    :new.PAYEE_CARRIER_ID,
                    :new.COMMENTS,
                    :new.LAST_UPDATED_SRC_TYPE,
                    :new.LAST_UPDATED_SRC,
                    NULL,                              -- no AUTH_SRC_TYPE
                    NULL,                                   -- no AUTH_SRC
                    :new.LAST_UPDATED_DTTM,
                    :new.LANE_ACCESSORIAL_ID,
                    :new.REASON_ID);
  vChgFlag := 1;
 END IF;
 -- Minimum Rate
 IF (   (:old.MINIMUM_RATE != :new.MINIMUM_RATE)
   OR (:old.MINIMUM_RATE IS NULL AND :new.MINIMUM_RATE IS NOT NULL)
   OR (:new.MINIMUM_RATE IS NULL AND :old.MINIMUM_RATE IS NOT NULL))
 THEN
  INS_RATING_EVENT (:new.LANE_ID,
                    :new.RATING_LANE_DTL_SEQ,
                    NULL,                                -- no RLD_RATE_ID
                    :new.TC_COMPANY_ID,
                    NULL,                                  -- no CHANGE_ID
                    'Min Rate',
                    :old.MINIMUM_RATE,
                    :new.MINIMUM_RATE,
                    :new.COMMENTS,
                    :new.LAST_UPDATED_SRC_TYPE,
                    :new.LAST_UPDATED_SRC,
                    NULL,                              -- no AUTH_SRC_TYPE
                    NULL,                                   -- no AUTH_SRC
                    :new.LAST_UPDATED_DTTM,
                    :new.LANE_ACCESSORIAL_ID,
                    :new.REASON_ID);
  vChgFlag := 1;
 END IF;
 -- currency_code
 IF (   (:old.CURRENCY_CODE != :new.CURRENCY_CODE)
   OR (:old.CURRENCY_CODE IS NULL AND :new.CURRENCY_CODE IS NOT NULL)
   OR (:new.CURRENCY_CODE IS NULL AND :old.CURRENCY_CODE IS NOT NULL))
 THEN
  INS_RATING_EVENT (:new.LANE_ID,
                    :new.RATING_LANE_DTL_SEQ,
                    NULL,                                -- no RLD_RATE_ID
                    :new.TC_COMPANY_ID,
                    NULL,                                  -- no CHANGE_ID
                    'CURRENCY_CODE',
                    :old.CURRENCY_CODE,
                    :new.CURRENCY_CODE,
                    :new.COMMENTS,
                    :new.LAST_UPDATED_SRC_TYPE,
                    :new.LAST_UPDATED_SRC,
                    NULL,                              -- no AUTH_SRC_TYPE
                    NULL,                                   -- no AUTH_SRC
                    :new.LAST_UPDATED_DTTM,
                    :new.LANE_ACCESSORIAL_ID,
                    :new.REASON_ID);
  vChgFlag := 1;
 END IF;
 -- minimum_size
 IF (   (:old.MINIMUM_SIZE != :new.MINIMUM_SIZE)
   OR (:old.MINIMUM_SIZE IS NULL AND :new.MINIMUM_SIZE IS NOT NULL)
   OR (:new.MINIMUM_SIZE IS NULL AND :old.MINIMUM_SIZE IS NOT NULL))
 THEN
  INS_RATING_EVENT (:new.LANE_ID,
                    :new.RATING_LANE_DTL_SEQ,
                    NULL,                                -- no RLD_RATE_ID
                    :new.TC_COMPANY_ID,
                    NULL,                                  -- no CHANGE_ID
                    'Min Qty',
                    :old.MINIMUM_SIZE,
                    :new.MINIMUM_SIZE,
                    :new.COMMENTS,
                    :new.LAST_UPDATED_SRC_TYPE,
                    :new.LAST_UPDATED_SRC,
                    NULL,                              -- no AUTH_SRC_TYPE
                    NULL,                                   -- no AUTH_SRC
                    :new.LAST_UPDATED_DTTM,
                    :new.LANE_ACCESSORIAL_ID,
                    :new.REASON_ID);
  vChgFlag := 1;
 END IF;
 -- maximum_size
 IF (   (:old.MAXIMUM_SIZE != :new.MAXIMUM_SIZE)
   OR (:old.MAXIMUM_SIZE IS NULL AND :new.MAXIMUM_SIZE IS NOT NULL)
   OR (:new.MAXIMUM_SIZE IS NULL AND :old.MAXIMUM_SIZE IS NOT NULL))
 THEN
  INS_RATING_EVENT (:new.LANE_ID,
                    :new.RATING_LANE_DTL_SEQ,
                    NULL,                                -- no RLD_RATE_ID
                    :new.TC_COMPANY_ID,
                    NULL,                                  -- no CHANGE_ID
                    'Max Qty',
                    :old.MAXIMUM_SIZE,
                    :new.MAXIMUM_SIZE,
                    :new.COMMENTS,
                    :new.LAST_UPDATED_SRC_TYPE,
                    :new.LAST_UPDATED_SRC,
                    NULL,                              -- no AUTH_SRC_TYPE
                    NULL,                                   -- no AUTH_SRC
                    :new.LAST_UPDATED_DTTM,
                    :new.LANE_ACCESSORIAL_ID,
                    :new.REASON_ID);
  vChgFlag := 1;
 END IF;
 -- is_auto_approve
 IF (   (:old.IS_AUTO_APPROVE != :new.IS_AUTO_APPROVE)
   OR (:old.IS_AUTO_APPROVE IS NULL AND :new.IS_AUTO_APPROVE IS NOT NULL)
   OR (:new.IS_AUTO_APPROVE IS NULL AND :old.IS_AUTO_APPROVE IS NOT NULL))
 THEN
  INS_RATING_EVENT (:new.LANE_ID,
                    :new.RATING_LANE_DTL_SEQ,
                    NULL,                                -- no RLD_RATE_ID
                    :new.TC_COMPANY_ID,
                    NULL,                                  -- no CHANGE_ID
                    'Is Auto Approve',
                    :old.IS_AUTO_APPROVE,
                    :new.IS_AUTO_APPROVE,
                    :new.COMMENTS,
                    :new.LAST_UPDATED_SRC_TYPE,
                    :new.LAST_UPDATED_SRC,
                    NULL,                              -- no AUTH_SRC_TYPE
                    NULL,                                   -- no AUTH_SRC
                    :new.LAST_UPDATED_DTTM,
                    :new.LANE_ACCESSORIAL_ID,
                    :new.REASON_ID);
  vChgFlag := 1;
 END IF;
 -- is_shipment_accessorial
 IF ( (:old.IS_SHIPMENT_ACCESSORIAL != :new.IS_SHIPMENT_ACCESSORIAL)
   OR (:old.IS_SHIPMENT_ACCESSORIAL IS NULL
       AND :new.IS_SHIPMENT_ACCESSORIAL IS NOT NULL)
   OR (:new.IS_SHIPMENT_ACCESSORIAL IS NULL
       AND :old.IS_SHIPMENT_ACCESSORIAL IS NOT NULL))
 THEN
  INS_RATING_EVENT (:new.LANE_ID,
                    :new.RATING_LANE_DTL_SEQ,
                    NULL,                                -- no RLD_RATE_ID
                    :new.TC_COMPANY_ID,
                    NULL,                                  -- no CHANGE_ID
                    'IS_SHIPMENT_ACCESSORIAL',
                    :old.IS_SHIPMENT_ACCESSORIAL,
                    :new.IS_SHIPMENT_ACCESSORIAL,
                    :new.COMMENTS,
                    :new.LAST_UPDATED_SRC_TYPE,
                    :new.LAST_UPDATED_SRC,
                    NULL,                              -- no AUTH_SRC_TYPE
                    NULL,                                   -- no AUTH_SRC
                    :new.LAST_UPDATED_DTTM,
                    :new.LANE_ACCESSORIAL_ID,
                    :new.REASON_ID);
  vChgFlag := 1;
 END IF;
 -- effective_dt
 IF (   (:old.EFFECTIVE_DT != :new.EFFECTIVE_DT)
   OR (:old.EFFECTIVE_DT IS NULL AND :new.EFFECTIVE_DT IS NOT NULL)
   OR (:new.EFFECTIVE_DT IS NULL AND :old.EFFECTIVE_DT IS NOT NULL))
 THEN
  INS_RATING_EVENT (:new.LANE_ID,
                    :new.RATING_LANE_DTL_SEQ,
                    NULL,                                -- no RLD_RATE_ID
                    :new.TC_COMPANY_ID,
                    NULL,                                  -- no CHANGE_ID
                    'EFFECTIVE_DT',
                    :old.EFFECTIVE_DT,
                    :new.EFFECTIVE_DT,
                    :new.COMMENTS,
                    :new.LAST_UPDATED_SRC_TYPE,
                    :new.LAST_UPDATED_SRC,
                    NULL,                              -- no AUTH_SRC_TYPE
                    NULL,                                   -- no AUTH_SRC
                    :new.LAST_UPDATED_DTTM,
                    :new.LANE_ACCESSORIAL_ID,
                    :new.REASON_ID);
  vChgFlag := 1;
 END IF;
 -- expiration_dt
 IF (   (:old.EXPIRATION_DT != :new.EXPIRATION_DT)
   OR (:old.EXPIRATION_DT IS NULL AND :new.EXPIRATION_DT IS NOT NULL)
   OR (:new.EXPIRATION_DT IS NULL AND :old.EXPIRATION_DT IS NOT NULL))
 THEN
  INS_RATING_EVENT (:new.LANE_ID,
                    :new.RATING_LANE_DTL_SEQ,
                    NULL,                                -- no RLD_RATE_ID
                    :new.TC_COMPANY_ID,
                    NULL,                                  -- no CHANGE_ID
                    'EXPIRATION_DT',
                    :old.EXPIRATION_DT,
                    :new.EXPIRATION_DT,
                    :new.COMMENTS,
                    :new.LAST_UPDATED_SRC_TYPE,
                    :new.LAST_UPDATED_SRC,
                    NULL,                              -- no AUTH_SRC_TYPE
                    NULL,                                   -- no AUTH_SRC
                    :new.LAST_UPDATED_DTTM,
                    :new.LANE_ACCESSORIAL_ID,
                    :new.REASON_ID);
  vChgFlag := 1;
 END IF;
 --Incoterm Id
 IF (:old.INCOTERM_ID IS NOT NULL)
 THEN
  SELECT INCOTERM_NAME
    INTO OldIncotermName
    FROM INCOTERM
   WHERE INCOTERM_ID = :old.INCOTERM_ID;
 END IF;
 IF (:new.INCOTERM_ID IS NOT NULL)
 THEN
  SELECT INCOTERM_NAME
    INTO NewIncotermName
    FROM INCOTERM
   WHERE INCOTERM_ID = :new.INCOTERM_ID;
 END IF;
 IF (   (:old.INCOTERM_ID != :new.INCOTERM_ID)
   OR (:old.INCOTERM_ID IS NULL AND :new.INCOTERM_ID IS NOT NULL)
   OR (:new.INCOTERM_ID IS NULL AND :old.INCOTERM_ID IS NOT NULL))
 THEN
  INS_RATING_EVENT (:new.LANE_ID,
                    :new.RATING_LANE_DTL_SEQ,
                    NULL,                                -- no RLD_RATE_ID
                    :new.TC_COMPANY_ID,
                    NULL,                                  -- no CHANGE_ID
                    'INCOTERM',
                    OldIncotermName,
                    NewIncotermName,
                    :new.COMMENTS,
                    :new.LAST_UPDATED_SRC_TYPE,
                    :new.LAST_UPDATED_SRC,
                    NULL,                              -- no AUTH_SRC_TYPE
                    NULL,                                   -- no AUTH_SRC
                    :new.LAST_UPDATED_DTTM,
                    :new.LANE_ACCESSORIAL_ID,
                    :new.REASON_ID);
  vChgFlag := 1;
 END IF;
 IF (vChgFlag = 0)
 THEN
  IF ( (:old.LAST_UPDATED_DTTM != :new.LAST_UPDATED_DTTM)
      OR (:old.LAST_UPDATED_DTTM IS NULL
          AND :new.LAST_UPDATED_DTTM IS NOT NULL)
      OR (:new.LAST_UPDATED_DTTM IS NULL
          AND :old.LAST_UPDATED_DTTM IS NOT NULL))
  THEN
     vOldValue :=
        TO_CHAR (:old.last_updated_dttm, 'DD-MON-YYYY HH:MI:SS AM');
     vNewValue :=
        TO_CHAR (:new.last_updated_dttm, 'DD-MON-YYYY HH:MI:SS AM');
     INS_RATING_EVENT (:new.LANE_ID,
                       :new.RATING_LANE_DTL_SEQ,
                       NULL,                             -- no RLD_RATE_ID
                       :new.TC_COMPANY_ID,
                       NULL,                               -- no CHANGE_ID
                       'LAST UPDATED DATETIME',
                       vOldValue,
                       vNewValue,
                       :new.COMMENTS,
                       :new.LAST_UPDATED_SRC_TYPE,
                       :new.LAST_UPDATED_SRC,
                       NULL,                           -- no AUTH_SRC_TYPE
                       NULL,                                -- no AUTH_SRC
                       :new.LAST_UPDATED_DTTM,
                       :new.LANE_ACCESSORIAL_ID,
                       :new.REASON_ID);
  END IF;
 END IF;
END;
/

create or replace TRIGGER CCODE_CONTACT_B_I1
 BEFORE INSERT
 ON CARRIER_CODE_CONTACT
 REFERENCING NEW AS NEW
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
BEGIN
 SELECT ROUND (NVL (MAX (CC_CONTACT_ID), 0) + 1)
 INTO :NEW.CC_CONTACT_ID
 FROM CARRIER_CODE_CONTACT
WHERE CARRIER_ID = :NEW.CARRIER_ID;
END;
/

create or replace TRIGGER FCLTY_AFT_INSRT
 AFTER INSERT
 ON FACILITY
 REFERENCING NEW AS NEW
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
BEGIN
 IF (BITAND (:NEW.FACILITY_TYPE_BITS, 8) = 8)
 THEN
  INSERT INTO WHSE_MASTER (WHSE,
                           CREATE_DATE_TIME,
                           MOD_DATE_TIME,
                           WHSE_MASTER_ID,
                           CLS_TIMEZONE_ID,
                           WM_VERSION_ID,
                           AUDIT_CREATED_SOURCE,
                           AUDIT_CREATED_SOURCE_TYPE,
                           AUDIT_CREATED_DTTM,
                           AUDIT_LAST_UPDATED_SOURCE,
                           AUDIT_LAST_UPDATED_SOURCE_TYPE,
                           AUDIT_LAST_UPDATED_DTTM,
                           MARK_FOR_DELETION,
                           USER_ID)
       VALUES (:NEW.WHSE,
               SYSDATE,
               SYSDATE,
               :NEW.FACILITY_ID,
               :NEW.FACILITY_TZ,
               1,
               :NEW.CREATED_SOURCE,
               :NEW.CREATED_SOURCE_TYPE,
               :NEW.CREATED_DTTM,
               :NEW.LAST_UPDATED_SOURCE,
               :NEW.LAST_UPDATED_SOURCE_TYPE,
               :NEW.LAST_UPDATED_DTTM,
               :NEW.MARK_FOR_DELETION,
               :NEW.CREATED_SOURCE);
 END IF;
END;
/

create or replace TRIGGER FCLTY_BEFR_DEL
 BEFORE DELETE
 ON FACILITY
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
BEGIN
  DELETE FROM WHSE_MASTER WHERE WHSE = :OLD.WHSE;
END;
/

create or replace TRIGGER FACILITY_B_IU_TR_2 before
  INSERT OR
  UPDATE OF CITY,
    STATE_PROV,
    POSTAL_CODE,
    COUNTRY_CODE ON FACILITY REFERENCING OLD AS OLD NEW AS NEW FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
DECLARE l_1q CHAR(1)      := CHR(39);
  l_select                                                                               VARCHAR2(64) := 'select    LONGITUDE, LATITUDE';
  l_from                                                                                 VARCHAR2(64) := ' from POSTAL_CODE';
  l_where                                                                                VARCHAR2(1024);
  l_cntry_code FACILITY.COUNTRY_CODE%TYPE;
  l_pstl_code FACILITY.POSTAL_CODE%TYPE;
  l_state_prov FACILITY.STATE_PROV%TYPE;
  l_city FACILITY.CITY%TYPE;
  BEGIN
    -- build WHERE clause
    IF ( :new.LATITUDE     IS NULL AND :new.LONGITUDE IS NULL ) THEN
      l_where              := ' where UPPER(COUNTRY_CODE) = :1 ';
      IF (:new.POSTAL_CODE IS NOT NULL) THEN
        l_where            := l_where || ' and UPPER(POSTAL_CODE) = :2 ';
      END IF;
      IF (:new.STATE_PROV IS NOT NULL) THEN
        l_where           := l_where || ' and UPPER(STATE_PROV) = :3 ';
      END IF;
      IF (:new.CITY IS NOT NULL) THEN
        l_where     := l_where || ' and UPPER(CITY)  = :4 ';
      END IF;
      l_cntry_code    := NVL(UPPER(:new.COUNTRY_CODE),'NULL');
      l_pstl_code     := UPPER(:new.POSTAL_CODE);
      l_state_prov    := UPPER(:new.STATE_PROV);
      l_city          := NVL(UPPER(REPLACE(:new.CITY, l_1q, l_1q)),'NULL');
      IF (l_pstl_code IS NOT NULL AND l_state_prov IS NOT NULL) THEN
        EXECUTE immediate l_select || l_from || l_where INTO :new.LONGITUDE,
        :new.LATITUDE USING l_cntry_code,
        l_pstl_code,
        l_state_prov,
        l_city;
      END IF;
      IF (l_pstl_code IS NULL AND l_state_prov IS NOT NULL) THEN
        EXECUTE immediate l_select || l_from || l_where INTO :new.LONGITUDE,
        :new.LATITUDE USING l_cntry_code,
        l_state_prov,
        l_city;
      END IF;
      IF (l_pstl_code IS NOT NULL AND l_state_prov IS NULL) THEN
        EXECUTE immediate l_select || l_from || l_where INTO :new.LONGITUDE,
        :new.LATITUDE USING l_cntry_code,
        l_pstl_code,
        l_city;
      END IF;
      IF (l_pstl_code IS NULL AND l_state_prov IS NULL) THEN
        EXECUTE immediate l_select || l_from || l_where INTO :new.LONGITUDE,
        :new.LATITUDE USING l_cntry_code,
        l_city;
      END IF;
    END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    :new.LONGITUDE := NULL;
    :new.LATITUDE  := NULL;
  WHEN TOO_MANY_ROWS THEN
    :new.LONGITUDE := NULL;
    :new.LATITUDE  := NULL;
  WHEN OTHERS THEN
    raise_application_error ( -20000, 'in FACILITY_B_IU_TR_2: ' || l_select || l_from || l_where );
  END FACILITY_B_IU_TR_2;
  /
  
create or replace TRIGGER FCLTY_AFT_UPDT
 AFTER UPDATE
 ON FACILITY
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
DECLARE
 V_NEWWHSE   NUMBER DEFAULT 0;
BEGIN
 IF (:NEW.FACILITY_TYPE_BITS = :OLD.FACILITY_TYPE_BITS)
 THEN
  IF (BITAND (:OLD.FACILITY_TYPE_BITS, 8) = 8)
  THEN
     IF (:NEW.WHSE <> :OLD.WHSE)
     THEN
        UPDATE WHSE_MASTER
           SET WHSE = (SELECT :NEW.WHSE FROM DUAL)
         WHERE WHSE_MASTER.WHSE_MASTER_ID = :OLD.FACILITY_ID;
     END IF;
     IF (:NEW.CREATED_DTTM <> :OLD.CREATED_DTTM)
     THEN
        UPDATE WHSE_MASTER
           SET CREATE_DATE_TIME = (SELECT :NEW.CREATED_DTTM FROM DUAL)
         WHERE WHSE_MASTER.WHSE_MASTER_ID = :OLD.FACILITY_ID;
     END IF;
     IF (:NEW.LAST_UPDATED_DTTM <> :OLD.LAST_UPDATED_DTTM)
     THEN
        UPDATE WHSE_MASTER
           SET MOD_DATE_TIME = (SELECT :NEW.LAST_UPDATED_DTTM FROM DUAL)
         WHERE WHSE_MASTER.WHSE_MASTER_ID = :OLD.FACILITY_ID;
     END IF;
     IF (:NEW.FACILITY_TZ <> :OLD.FACILITY_TZ)
     THEN
        UPDATE WHSE_MASTER
           SET CLS_TIMEZONE_ID = (SELECT :NEW.FACILITY_TZ FROM DUAL)
         WHERE WHSE_MASTER.WHSE_MASTER_ID = :OLD.FACILITY_ID;
     END IF;
  END IF;
 ELSE
  IF (BITAND (:NEW.FACILITY_TYPE_BITS, 8) = 8)
  THEN
     SELECT COUNT (*)
       INTO V_NEWWHSE
       FROM DUAL
      WHERE EXISTS
               (SELECT WHSE
                  FROM WHSE_MASTER
                 WHERE WHSE_MASTER_ID = :OLD.FACILITY_ID);
     IF (V_NEWWHSE = 0)
     THEN
        INSERT INTO WHSE_MASTER (WHSE,
                                 CREATE_DATE_TIME,
                                 MOD_DATE_TIME,
                                 WHSE_MASTER_ID,
                                 CLS_TIMEZONE_ID,
                                 WM_VERSION_ID,
                                 AUDIT_CREATED_SOURCE,
                                 AUDIT_CREATED_SOURCE_TYPE,
                                 AUDIT_CREATED_DTTM,
                                 AUDIT_LAST_UPDATED_SOURCE,
                                 AUDIT_LAST_UPDATED_SOURCE_TYPE,
                                 AUDIT_LAST_UPDATED_DTTM,
                                 MARK_FOR_DELETION,
                                 USER_ID)
             VALUES (
                       NVL (:NEW.WHSE, :OLD.WHSE),
                       SYSDATE,
                       SYSDATE,
                       NVL (:NEW.FACILITY_ID, :OLD.FACILITY_ID),
                       NVL (:NEW.FACILITY_TZ, :OLD.FACILITY_TZ),
                       1,
                       NVL (:NEW.CREATED_SOURCE, :OLD.CREATED_SOURCE),
                       NVL (:NEW.CREATED_SOURCE_TYPE,
                            :OLD.CREATED_SOURCE_TYPE),
                       SYSDATE,
                       NVL (:NEW.LAST_UPDATED_SOURCE,
                            :OLD.LAST_UPDATED_SOURCE),
                       NVL (:NEW.LAST_UPDATED_SOURCE_TYPE,
                            :OLD.LAST_UPDATED_SOURCE_TYPE),
                       NVL (:NEW.LAST_UPDATED_DTTM,
                            :OLD.LAST_UPDATED_DTTM),
                       NVL (:NEW.MARK_FOR_DELETION,
                            :OLD.MARK_FOR_DELETION),
                       NVL (:NEW.CREATED_SOURCE, :OLD.CREATED_SOURCE));
     END IF;
  END IF;
 END IF;
 UPDATE WHSE_MASTER
  SET (AUDIT_CREATED_SOURCE,
       AUDIT_CREATED_SOURCE_TYPE,
       AUDIT_CREATED_DTTM,
       AUDIT_LAST_UPDATED_SOURCE,
       AUDIT_LAST_UPDATED_SOURCE_TYPE,
       AUDIT_LAST_UPDATED_DTTM,
       MARK_FOR_DELETION) =
         (SELECT :NEW.CREATED_SOURCE,
                 :NEW.CREATED_SOURCE_TYPE,
                 :NEW.CREATED_DTTM,
                 :NEW.LAST_UPDATED_SOURCE,
                 :NEW.LAST_UPDATED_SOURCE_TYPE,
                 :NEW.LAST_UPDATED_DTTM,
                 :NEW.MARK_FOR_DELETION
            FROM DUAL)
WHERE WHSE_MASTER.WHSE_MASTER_ID = :OLD.FACILITY_ID;
END;
/

create or replace TRIGGER FAC_NOTE_B_I_TRG_1
 BEFORE INSERT
 ON FACILITY_NOTE
 REFERENCING NEW AS N
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
DECLARE
 VRECCNT   INTEGER DEFAULT NULL;
BEGIN
 FOR EACH_FAC IN (SELECT NVL (MAX (note_seq), 0) + 1 AS note_seq
                  FROM facility_note
                 WHERE facility_id = :n.FACILITY_ID)
 LOOP
  vreccnt := EACH_FAC.note_seq;
  :n.note_seq := VRECCNT;
  :n.CREATED_DTTM := SYSDATE;
 END LOOP;
 IF (VRECCNT IS NULL)
 THEN
  VRECCNT := 1;
  :n.note_seq := VRECCNT;
  :n.CREATED_DTTM := SYSDATE;
 END IF;
END;
/

create or replace TRIGGER SURGE_CAPACITY_BI_TR
   BEFORE INSERT
   ON "SURGE_CAPACITY"
   REFERENCING OLD AS OLD NEW AS NEW
   FOR EACH ROW
DECLARE
   rec_cnt   NUMBER;
BEGIN
   rec_cnt := 1;

   IF INSERTING AND :new.surge_capacity_id IS NULL
   THEN
      WHILE (rec_cnt > 0)
      LOOP
         SELECT seq_surge_capacity_id.NEXTVAL
           INTO :new.surge_capacity_id
           FROM DUAL;

         SELECT MAX (surge_capacity_id)
           INTO rec_cnt
           FROM surge_capacity
          WHERE surge_capacity_id = :new.surge_capacity_id;
      END LOOP;
   END IF;
END;
/

create or replace TRIGGER USR_AFT_INS
   AFTER INSERT
   ON UCL_USER
   FOR EACH ROW
BEGIN
   IF (:NEW.COPY_FROM_USER IS NULL)
   THEN
      INSERT INTO USER_PROFILE (USER_PROFILE_ID,
                                LOGIN_USER_ID,
                                MENU_ID,
                                RF_MENU_ID,
                                CREATE_DATE_TIME,
                                MOD_DATE_TIME,
                                USER_ID)
           VALUES (:NEW.UCL_USER_ID,
                   :NEW.USER_NAME,
                   2124,
                   3111,
                   :NEW.CREATED_DTTM,
                   :NEW.CREATED_DTTM,
                   'SYSTEM');
   ELSE
      INSERT INTO USER_PROFILE (USER_PROFILE_ID,
                                LOGIN_USER_ID,
                                MENU_ID,
                                RF_MENU_ID,
                                RESTR_TASK_GRP_TO_DFLT,
                                RESTR_MENU_MODE_TO_DFLT,
                                DFLT_RF_MENU_MODE,
                                LANG_ID,
                                LAST_LOCN,
                                LAST_WORK_GRP,
                                LAST_WORK_AREA,
                                ALLOW_TASK_INT_CHG,
                                NBR_OF_TASK_TO_DSP,
                                CURR_TASK_GRP,
                                TASK_GRP_JUMP_FLAG,
                                AUTO_3PL_LOGIN_FLAG,
                                VOCOLLECT_PUTAWAY_FLAG,
                                VOCOLLECT_REPLEN_FLAG,
                                VOCOLLECT_PACKING_FLAG,
                                CLS_TIMEZONE_ID,
                                WM_VERSION_ID,
                                DFLT_TASK_INT,
                                CREATE_DATE_TIME,
                                MOD_DATE_TIME,
                                USER_ID,
                                SCREEN_TYPE_ID)
         (SELECT :NEW.UCL_USER_ID,
                 :NEW.USER_NAME,
                 MENU_ID,
                 RF_MENU_ID,
                 RESTR_TASK_GRP_TO_DFLT,
                 RESTR_MENU_MODE_TO_DFLT,
                 DFLT_RF_MENU_MODE,
                 LANG_ID,
                 LAST_LOCN,
                 LAST_WORK_GRP,
                 LAST_WORK_AREA,
                 ALLOW_TASK_INT_CHG,
                 NBR_OF_TASK_TO_DSP,
                 CURR_TASK_GRP,
                 TASK_GRP_JUMP_FLAG,
                 AUTO_3PL_LOGIN_FLAG,
                 VOCOLLECT_PUTAWAY_FLAG,
                 VOCOLLECT_REPLEN_FLAG,
                 VOCOLLECT_PACKING_FLAG,
                 CLS_TIMEZONE_ID,
                 1,
                 DFLT_TASK_INT,
                 :NEW.CREATED_DTTM,
                 :NEW.CREATED_DTTM,
                 'SYSTEM',
                 SCREEN_TYPE_ID
            FROM USER_PROFILE
           WHERE USER_PROFILE.LOGIN_USER_ID = :NEW.COPY_FROM_USER);

      INSERT INTO USER_TASK_GRP (LOGIN_USER_ID,
                                 TASK_GRP,
                                 STAT_CODE,
                                 USER_ID,
                                 CREATE_DATE_TIME,
                                 MOD_DATE_TIME,
                                 TASK_GRP_JUMP_PRTY,
                                 REOCCUR_TASK_INTERVAL,
                                 USER_TASK_GRP_ID,
                                 USER_PROFILE_ID,
                                 WM_VERSION_ID,
                                 REOCCUR_INT)
         (SELECT :NEW.USER_NAME,
                 TASK_GRP,
                 STAT_CODE,
                 USER_ID,
                 CREATE_DATE_TIME,
                 MOD_DATE_TIME,
                 TASK_GRP_JUMP_PRTY,
                 REOCCUR_TASK_INTERVAL,
                 USER_TASK_GRP_ID_SEQ.NEXTVAL,
                 :NEW.UCL_USER_ID,
                 WM_VERSION_ID,
                 REOCCUR_INT
            FROM USER_TASK_GRP
           WHERE LOGIN_USER_ID = :NEW.COPY_FROM_USER);

      INSERT INTO LRF_USER_PRO (USER_PRO_ID,
                                EMPLYE_ID,
                                USER_ID,
                                PRTR_REQSTR,
                                CREATED_DTTM,
                                LAST_UPDATED_DTTM)
         (SELECT USER_PROFILE_ID_SEQ.NEXTVAL,
                 EMPLYE_ID,
                 :NEW.USER_NAME,
                 PRTR_REQSTR,
                 :NEW.CREATED_DTTM,
                 :NEW.CREATED_DTTM
            FROM LRF_USER_PRO
           WHERE USER_ID = :NEW.COPY_FROM_USER);

      INSERT INTO USER_DEFAULT (USER_DEFAULT_ID,
                                UCL_USER_ID,
                                PARAMETER_NAME,
                                PARAMETER_VALUE,
                                CREATED_DTTM,
                                LAST_UPDATED_DTTM)
         (SELECT SEQ_USER_DEFAULT_ID.NEXTVAL,
                 :NEW.UCL_USER_ID,
                 PARAMETER_NAME,
                 PARAMETER_VALUE,
                 :NEW.CREATED_DTTM,
                 :NEW.CREATED_DTTM
            FROM USER_DEFAULT
           WHERE UCL_USER_ID IN
                    (SELECT UU.USER_PROFILE_ID
                       FROM USER_PROFILE UU
                      WHERE UU.LOGIN_USER_ID = :NEW.COPY_FROM_USER)
                 AND PARAMETER_NAME NOT IN
                        ('USER_DEFAULT_BU_ID', 'USER_DEFAULT_REGION_ID'));
   END IF;
END;
/

create or replace TRIGGER USR_AFT_DEL
 AFTER DELETE
 ON UCL_USER
 FOR EACH ROW
BEGIN
 DELETE FROM USER_PROFILE
     WHERE LOGIN_USER_ID = :OLD.USER_NAME;
END;
/

create or replace TRIGGER USER_COPY_TRIGGER
   AFTER INSERT
   ON UCL_USER
   REFERENCING NEW AS NEW OLD AS OLD
   FOR EACH ROW
   WHEN (NEW.COPY_FROM_USER IS NOT NULL)
DECLARE
   E_EMP_ID                UCL_USER.UCL_USER_ID%TYPE;
   E_EMP_DTL_ID            E_EMP_DTL.EMP_DTL_ID%TYPE;
   E_EMP_INC_ID            E_EMP_INC.EMP_INC_ID%TYPE;
   E_EMP_PAY_OVERRIDE_ID   E_EMP_PAY_OVERRIDE.EMP_PAY_OVERRIDE_ID%TYPE;
   E_EMP_REFLECT_STD_ID    E_EMP_REFLECT_STD_CONFIG.EMP_REFLECT_STD_ID%TYPE;
   E_TEAM_EMP_CONFIG_ID    E_TEAM_EMP_CONFIG.TEAM_EMP_CONFIG_ID%TYPE;
BEGIN
   SELECT USER_PROFILE_ID
     INTO E_EMP_ID
     FROM USER_PROFILE
    WHERE LOGIN_USER_ID = :NEW.COPY_FROM_USER ;

   IF E_EMP_ID IS NOT NULL
   THEN
      INSERT INTO E_EMP_DTL
         SELECT :NEW.UCL_USER_ID,
                EFF_DATE_TIME,
                EMP_STAT_ID,
                PAY_RATE,
                PAY_SCALE_ID,
                SPVSR_EMP_ID,
                DEPT_ID,
                SHIFT_ID,
                ROLE_ID,
                USER_DEF_FIELD_1,
                USER_DEF_FIELD_2,
                CMNT,
                SYSDATE,
                SYSDATE,
                :NEW.USER_NAME,
                WHSE,
                JOB_FUNC_ID,
                STARTUP_TIME,
                CLEANUP_TIME,
                MISC_TXT_1,
                MISC_TXT_2,
                MISC_NUM_1,
                MISC_NUM_2,
                DFLT_PERF_GOAL,
                VERSION_ID,
                IS_SUPER,
                EMP_DTL_ID_SEQ.NEXTVAL,
                SYSDATE,
                NULL,
                EXCLUDE_AUTO_CICO
           FROM (SELECT *
                   FROM E_EMP_DTL
                  WHERE EFF_DATE_TIME IN
                           (  SELECT MAX (EFF_DATE_TIME)
                                FROM E_EMP_DTL
                            GROUP BY EMP_ID, WHSE, EMP_STAT_ID
                              HAVING WHSE IN
                                        (SELECT DISTINCT WHSE FROM E_EMP_DTL)
                                     AND EMP_ID = E_EMP_ID and EMP_STAT_ID != (SELECT EMP_STAT_ID  FROM E_EMP_STAT_CODE WHERE EMP_STAT_CODE = 'INACTIVE'))
                        AND EMP_ID = E_EMP_ID);

      INSERT INTO E_EMP_INC
         SELECT E_EMP_INC_ID_SEQ.NEXTVAL,
                :NEW.UCL_USER_ID,
                INC_CODE_ID,
                EFF_BEGIN_DATE,
                EFF_END_DATE,
                WHSE,
                MISC_TXT_1,
                MISC_TXT_2,
                MISC_NUM_1,
                MISC_NUM_2,
                SYSDATE,
                SYSDATE,
                :NEW.USER_NAME,
                VERSION_ID
           FROM (SELECT *
                   FROM E_EMP_INC
                  WHERE EFF_BEGIN_DATE IN
                           (  SELECT MAX (EFF_BEGIN_DATE)
                                FROM E_EMP_INC
                            GROUP BY EMP_ID, WHSE
                              HAVING WHSE IN
                                        (SELECT DISTINCT WHSE FROM E_EMP_INC)
                                     AND EMP_ID IN (SELECT EMP_ID FROM E_EMP_DTL WHERE EMP_ID = E_EMP_ID AND EMP_STAT_ID != (SELECT EMP_STAT_ID  FROM E_EMP_STAT_CODE WHERE EMP_STAT_CODE = 'INACTIVE')))
                        AND EMP_ID = E_EMP_ID);

      INSERT INTO E_EMP_PAY_OVERRIDE
         SELECT E_EMP_PAY_OVERRIDE_ID_SEQ.NEXTVAL,
                :NEW.UCL_USER_ID,
                JOB_FUNC_ID,
                SHIFT_ID,
                PAY_SCALE_ID,
                EFF_BEGIN_DATE,
                EFF_END_DATE,
                WHSE,
                MISC_TXT_1,
                MISC_TXT_2,
                MISC_NUM_1,
                MISC_NUM_2,
                SYSDATE,
                SYSDATE,
                :NEW.USER_NAME,
                VERSION_ID
           FROM (SELECT *
                   FROM E_EMP_PAY_OVERRIDE
                  WHERE EFF_BEGIN_DATE IN
                           (  SELECT MAX (EFF_BEGIN_DATE)
                                FROM E_EMP_PAY_OVERRIDE
                            GROUP BY EMP_ID, WHSE
                              HAVING WHSE IN
                                        (SELECT DISTINCT WHSE
                                           FROM E_EMP_PAY_OVERRIDE)
                                     AND EMP_ID IN (SELECT EMP_ID FROM E_EMP_DTL WHERE EMP_ID = E_EMP_ID AND EMP_STAT_ID != (SELECT EMP_STAT_ID  FROM E_EMP_STAT_CODE WHERE EMP_STAT_CODE = 'INACTIVE')))
                        AND EMP_ID = E_EMP_ID);

      INSERT INTO E_EMP_PERF_GOAL
         SELECT :NEW.UCL_USER_ID,
                ACT_ID,
                EFF_DATE,
                PERF_GOAL,
                ADDNL_PAY_AMT,
                SYSDATE,
                SYSDATE,
                :NEW.USER_NAME,
                WHSE,
                MISC_TXT_1,
                MISC_TXT_2,
                MISC_NUM_1,
                MISC_NUM_2,
                VERSION_ID
           FROM (SELECT *
                   FROM E_EMP_PERF_GOAL
                  WHERE EFF_DATE IN
                           (  SELECT MAX (EFF_DATE)
                                FROM E_EMP_PERF_GOAL
                            GROUP BY EMP_ID, WHSE
                              HAVING WHSE IN
                                        (SELECT DISTINCT WHSE
                                           FROM E_EMP_PERF_GOAL)
                                     AND EMP_ID IN (SELECT EMP_ID FROM E_EMP_DTL WHERE EMP_ID = E_EMP_ID AND EMP_STAT_ID != (SELECT EMP_STAT_ID  FROM E_EMP_STAT_CODE WHERE EMP_STAT_CODE = 'INACTIVE')))
                        AND EMP_ID = E_EMP_ID);

      INSERT INTO E_EMP_REFLECT_STD_CONFIG
         SELECT EMP_REFLECT_STD_ID_SEQ.NEXTVAL,
                :NEW.UCL_USER_ID,
                EFF_BEGIN_DATE,
                EFF_END_DATE,
                DAY_ID,
                START_TIME,
                END_TIME,
                REFLECT_GROUP_CODE,
                WHSE,
                STAT_CODE,
                SYSDATE,
                SYSDATE,
                :NEW.USER_NAME,
                MISC_TXT_1,
                MISC_TXT_2,
                MISC_NUM_1,
                MISC_NUM_2,
                VERSION_ID
           FROM (SELECT *
                   FROM E_EMP_REFLECT_STD_CONFIG
                  WHERE EFF_BEGIN_DATE IN
                           (  SELECT MAX (EFF_BEGIN_DATE)
                                FROM E_EMP_REFLECT_STD_CONFIG
                            GROUP BY EMP_ID, WHSE
                              HAVING WHSE IN
                                        (SELECT DISTINCT WHSE
                                           FROM E_EMP_REFLECT_STD_CONFIG)
                                     AND EMP_ID IN (SELECT EMP_ID FROM E_EMP_DTL WHERE EMP_ID = E_EMP_ID AND EMP_STAT_ID != (SELECT EMP_STAT_ID  FROM E_EMP_STAT_CODE WHERE EMP_STAT_CODE = 'INACTIVE')))
                        AND EMP_ID = E_EMP_ID);

      INSERT INTO E_TEAM_EMP_CONFIG
         SELECT E_TEAM_EMP_CONFIG_ID_SEQ.NEXTVAL,
                :NEW.UCL_USER_ID,
                EFF_BEGIN_DATE,
                EFF_END_DATE,
                DAY_ID,
                TEAM_ID,
                ACT_ID,
                START_TIME,
                END_TIME,
                SYSDATE,
                SYSDATE,
                :NEW.USER_NAME,
                WHSE,
                STAT_CODE,
                MISC_TXT_1,
                MISC_TXT_2,
                MISC_NUM_1,
                MISC_NUM_2,
                VERSION_ID
           FROM (SELECT *
                   FROM E_TEAM_EMP_CONFIG
                  WHERE EFF_BEGIN_DATE IN
                           (  SELECT MAX (EFF_BEGIN_DATE)
                                FROM E_TEAM_EMP_CONFIG
                            GROUP BY EMP_ID, WHSE
                              HAVING WHSE IN
                                        (SELECT DISTINCT WHSE
                                           FROM E_TEAM_EMP_CONFIG)
                                     AND EMP_ID IN (SELECT EMP_ID FROM E_EMP_DTL WHERE EMP_ID = E_EMP_ID AND EMP_STAT_ID != (SELECT EMP_STAT_ID  FROM E_EMP_STAT_CODE WHERE EMP_STAT_CODE = 'INACTIVE')))
                        AND EMP_ID = E_EMP_ID);
   END IF;
EXCEPTION
   WHEN NO_DATA_FOUND
   THEN
      E_EMP_ID := NULL;
END;
/

create or replace TRIGGER TR_LABOR_CRITERIA
 BEFORE INSERT
 ON LABOR_CRITERIA
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
DECLARE
 ID   NUMBER (9);
BEGIN
 IF :NEW.CRIT_ID IS NULL
 THEN
  SELECT LABOR_CRITERIA_ID_SEQ.NEXTVAL INTO :NEW.CRIT_ID FROM DUAL;
 END IF;
END;
/

create or replace TRIGGER COMB_LANE_DTL_BIU_TR
 BEFORE INSERT OR UPDATE
 ON COMB_LANE_DTL
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
DECLARE
BEGIN
 IF (INSERTING)
 THEN
  IF (:new.LANE_DTL_SEQ IS NULL)
  THEN
     SELECT NVL (MAX (LANE_DTL_SEQ), 0) + 1
       INTO :new.LANE_DTL_SEQ
       FROM COMB_LANE_DTL
      WHERE TC_COMPANY_ID = :new.TC_COMPANY_ID AND LANE_ID = :new.LANE_ID;
  END IF;
 END IF;
 UPDATE COMB_LANE
  SET LAST_UPDATED_SOURCE_TYPE = :new.LAST_UPDATED_SOURCE_TYPE,
      LAST_UPDATED_SOURCE = :new.LAST_UPDATED_SOURCE,
      LAST_UPDATED_DTTM = :new.LAST_UPDATED_DTTM
WHERE TC_COMPANY_ID = :new.TC_COMPANY_ID AND LANE_ID = :new.LANE_ID;
END COMB_LANE_DTL_BIU_TR;
/

create or replace TRIGGER LOCN_HDR_AIU_INTG
    AFTER UPDATE
    ON LOCN_HDR
    REFERENCING NEW AS new OLD AS OLD
    FOR EACH ROW
DECLARE
    record_exists             NUMBER (1);
    order_streaming_enabled   NUMBER (1);
BEGIN
    SELECT CASE
               WHEN LOWER (TO_CHAR (SUBSTR (VALUE, 0, 4))) = 'true' THEN 1
               ELSE 0
           END
      INTO order_streaming_enabled
      FROM APPLICATION_CONFIGURATION
     WHERE KEY = 'orderstreaming.enabled';

    SELECT CASE
               WHEN EXISTS
                        (SELECT 1
                           FROM BASE_DATA_DELTA
                          WHERE     OBJECT_TYPE = 'LOCATION'
                                AND OBJECT_ID = :old.LOCN_ID)
               THEN
                   1
               ELSE
                   0
           END
      INTO record_exists
      FROM DUAL;

    IF (record_exists = 0 AND order_streaming_enabled = 1)
    THEN
        INSERT INTO base_data_delta (object_type,
                                     object_id,
                                     company_id,
                                     action_type,
                                     created_dttm)
             VALUES ('LOCATION',
                     :old.LOCN_ID,
                     NULL,
                     'UPDATE',
                     CURRENT_TIMESTAMP);
    END IF;
END;
/

create or replace TRIGGER CARRIER_CODE_A_I_TR_1
 AFTER INSERT
 ON CARRIER_CODE
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
WHEN (NVL (SYS_CONTEXT ('USERENV', 'MODULE'), 'DUMMY') != 'CONFIG_DIRECTOR')
DECLARE
 V_DL_ID   NUMBER;
 V_COUNT   NUMBER;
 V_CNT     NUMBER;
BEGIN
 SELECT COUNT(*)
 INTO V_CNT
 FROM DISTRIBUTION_LIST
 WHERE TC_COMPANY_ID = :NEW.TC_COMPANY_ID AND IS_PREFERRED_LIST = 1 ;
  IF V_CNT = 0
 THEN
	INSERT INTO DISTRIBUTION_LIST
(TC_COMPANY_ID,DESCRIPTION,IS_PREFERRED_LIST,TC_CONTACT_ID)
VALUES (:NEW.TC_COMPANY_ID,'All Company Carriers',1,0);
	INSERT INTO DISTRIBUTION_LIST
(TC_COMPANY_ID,DESCRIPTION,IS_PREFERRED_LIST,TC_CONTACT_ID)
	VALUES(:NEW.TC_COMPANY_ID,'All Lane Carriers',2,0);
 END IF;
SELECT DL_ID
 INTO V_DL_ID
 FROM DISTRIBUTION_LIST
 WHERE TC_COMPANY_ID = :NEW.TC_COMPANY_ID AND IS_PREFERRED_LIST = 1 ;
 SELECT COUNT (TP_COMPANY_ID)
 INTO V_COUNT
 FROM DISTRIB_LIST_MEMBER
WHERE DL_ID = V_DL_ID AND TP_COMPANY_ID = :NEW.TP_COMPANY_ID;
 IF V_COUNT = 0
 THEN
  INSERT INTO DISTRIB_LIST_MEMBER (DL_ID, TP_COMPANY_ID)
       VALUES (V_DL_ID, :NEW.TP_COMPANY_ID);
 END IF;
END;
/

create or replace TRIGGER CARRIER_CODE_B_D_TR_1
    BEFORE DELETE
    ON CARRIER_CODE
    REFERENCING OLD AS OLD NEW AS NEW
    FOR EACH ROW
BEGIN
    DELETE FROM DISTRIB_LIST_MEMBER
          WHERE TP_COMPANY_ID = :OLD.TP_COMPANY_ID;

    DELETE FROM DISTRIBUTION_LIST
          WHERE     TC_COMPANY_ID = :OLD.TC_COMPANY_ID
                AND description = 'All Company Carriers';

    DELETE FROM DISTRIBUTION_LIST
          WHERE     TC_COMPANY_ID = :OLD.TC_COMPANY_ID
                AND description = 'All Lane Carriers';
END;
/

create or replace TRIGGER SYS_CODE_AIU_INTG
    AFTER UPDATE
    ON SYS_CODE
    REFERENCING NEW AS new OLD AS OLD
    FOR EACH ROW
DECLARE
    record_exists             NUMBER (1);
    order_streaming_enabled   NUMBER (1);
BEGIN
    SELECT CASE
               WHEN EXISTS
                        (SELECT 1
                           FROM BASE_DATA_DELTA
                          WHERE     OBJECT_TYPE = 'SYSTEM_CODE'
                                AND OBJECT_ID =
                                           :old.REC_TYPE
                                        || ':'
                                        || :old.CODE_TYPE
                                        || ':'
                                        || :old.CODE_ID)
               THEN
                   1
               ELSE
                   0
           END
      INTO record_exists
      FROM DUAL;

    SELECT CASE
               WHEN LOWER (TO_CHAR (SUBSTR (VALUE, 0, 4))) = 'true' THEN 1
               ELSE 0
           END
      INTO order_streaming_enabled
      FROM APPLICATION_CONFIGURATION
     WHERE KEY = 'orderstreaming.enabled';

    IF (record_exists = 0 AND order_streaming_enabled = 1)
    THEN
        INSERT INTO base_data_delta (object_type,
                                     object_id,
                                     company_id,
                                     action_type,
                                     created_dttm)
                 VALUES (
                            'SYSTEM_CODE',
                               :old.REC_TYPE
                            || ':'
                            || :old.CODE_TYPE
                            || ':'
                            || :old.CODE_ID,
                            NULL,
                            'UPDATE',
                            CURRENT_TIMESTAMP);
    END IF;
END;
/

create or replace TRIGGER CD_SYS_CODE_AIU_INTG
    AFTER UPDATE
    ON CD_SYS_CODE
    REFERENCING NEW AS new OLD AS OLD
    FOR EACH ROW
DECLARE
    record_exists             NUMBER (1);
    order_streaming_enabled   NUMBER (1);
BEGIN
    SELECT CASE
               WHEN EXISTS
                        (SELECT 1
                           FROM BASE_DATA_DELTA
                          WHERE     OBJECT_TYPE = 'SYSTEM_CODE'
                                AND OBJECT_ID =
                                           :old.REC_TYPE
                                        || ':'
                                        || :old.CODE_TYPE
                                        || ':'
                                        || :old.CD_MASTER_ID
                                        || ':'
                                        || :old.CODE_ID)
               THEN
                   1
               ELSE
                   0
           END
      INTO record_exists
      FROM DUAL;

    SELECT CASE
               WHEN LOWER (TO_CHAR (SUBSTR (VALUE, 0, 4))) = 'true' THEN 1
               ELSE 0
           END
      INTO order_streaming_enabled
      FROM APPLICATION_CONFIGURATION
     WHERE KEY = 'orderstreaming.enabled';

    IF (record_exists = 0 AND order_streaming_enabled = 1)
    THEN
        INSERT INTO base_data_delta (object_type,
                                     object_id,
                                     company_id,
                                     action_type,
                                     created_dttm)
                 VALUES (
                            'SYSTEM_CODE',
                               :old.REC_TYPE
                            || ':'
                            || :old.CODE_TYPE
                            || ':'
                            || :old.CD_MASTER_ID
                            || ':'
                            || :old.CODE_ID,
                            NULL,
                            'UPDATE',
                            CURRENT_TIMESTAMP);
    END IF;
END;
/
spool off;


