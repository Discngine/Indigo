-- Copyright (C) from 2009 to Present EPAM Systems.
-- 
-- This file is part of Indigo toolkit.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
-- http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

Define USER_NAME = &1
Define USER_PASS = &2
Define ORACLE_USERNAME = &3
Define ORACLE_AUTH_TOKEN = &4
Define WALLET_URI = &5
Define LISTENER_URL = &6
Define LISTENER_HOSTNAME = &7

BEGIN
DBMS_CLOUD.CREATE_CREDENTIAL (
  credential_name   => 'CREDS_BINGO',
  username          => '&&ORACLE_USERNAME',
  password          => '&&ORACLE_AUTH_TOKEN');
END;
/

CREATE DIRECTORY wallet_dir AS 'directory_location';

BEGIN
DBMS_CLOUD.GET_OBJECT (
  credential_name     => 'CREDS_BINGO',
  object_uri          => '&&WALLET_URI',
  directory_name      => 'WALLET_DIR'
);
END;
/

BEGIN
DBMS_CLOUD_FUNCTION.CREATE_CATALOG (
  library_name               => 'bingolib',
  library_listener_url       => '&&LISTENER_URL',
  library_wallet_dir_name    => 'wallet_dir',
  library_ssl_server_cert_dn => 'CN=&&LISTENER_HOSTNAME',
  library_remote_path        => '/u01/app/oracle/extproc_libs/extprocutils.so'
);
END;
/

Set Verify Off
spool bingo_init;

column TBS_TYPE new_value TBS_TYPE
select case when version like '9.%' then null else 'BIGFILE' end TBS_TYPE from v$instance;

create user &USER_NAME
  identified by &USER_PASS
;
GRANT EXECUTE ON admin.bingolib TO bingo;
CREATE SYNONYM bingo.bingolib FOR admin.bingolib;

grant connect to &USER_NAME;
grant create type to &USER_NAME;
grant create table to &USER_NAME;
grant create operator to &USER_NAME;
grant create procedure to &USER_NAME;
grant create sequence to &USER_NAME;
grant create indextype to &USER_NAME;
grant unlimited tablespace to &USER_NAME;
grant create trigger to &USER_NAME;
grant administer database trigger to &USER_NAME;
grant select any table to &USER_NAME;

spool off;

exit;