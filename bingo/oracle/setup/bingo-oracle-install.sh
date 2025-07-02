#!/bin/sh
# Copyright (C) from 2009 to Present EPAM Systems.
# 
# This file is part of Indigo toolkit.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

libdir=$ORACLE_HOME/lib
dbaname="system"
dbapass=
instance=
bingoname="bingo"
bingopass="bingo"
y=

usage ()
{
echo 'Usage: bingo-oracle-install.sh [parameters]'
echo 'Parameters:'
echo '  -?, -help'
echo '    Print this help message'
echo '  -libdir path'
echo '    Target directory to install libbingo-oracle'$libext' (defaut $ORACLE_HOME/lib).'
echo '    If the directory does not exist, it will be created.'
echo '  -dbaname name'
echo '    Database administrator login (default "system").'
echo '  -dbapass password'
echo '    Database administrator password (no default).'
echo '    If the password is not specified, you will have to enter it later.'
echo '  -instance instance'
echo '    Database instance (default instance by default).'
echo '    You can specify full address like "server:1521/instance" as well.'
echo '  -bingoname name'
echo '    Name of cartridge pseudo-user (default "bingo").'
echo '  -bingopass password'
echo '    Password of the pseudo-user (default "bingo").'
echo '  -mode mode'
echo '    Mode of installation for now only autonomous is supported.'
echo '  -oracleusername name'
echo '    Oracle username for Autonomous Database (required in autonomous mode). Example: idcs-federation/<your_email>'
echo '  -oracleauthtoken token'
echo '    Oracle authentication token for getting wallet in the bucket (required in autonomous mode).'
echo '  -walleturi uri'
echo '    URI of the bucket with wallet (required in autonomous mode). Could also be a Pre-authenticated Request URL.'
echo '  -walletdir path'
echo '    Directory where the wallet exists (required in autonomous mode). You can get the wallet with the ui or the cli.'
echo '  -listenerurl url'
echo '    Listener URL for the Autonomous Database (required in autonomous mode). Use the DNS.'
echo '  -listenerhostname hostname'
echo '    Listener hostname for the Autonomous Database (required in autonomous mode). Get it with hostname command.'
echo '  -y'
echo '    Do not ask for confirmation.'
}

libext=".so"
if [ -f "lib/libbingo-oracle.dylib" ]; then
  libext=".dylib"
fi

while [ "$#" != 0 ]; do
  case "$1" in
     -help | '-?' | '/?')
        usage
        exit 0
        ;;
     -libdir)
        shift
        libdir=$1
        ;;
           -dbaname)
        shift
        dbaname=$1
        ;;
     -dbapass)
        shift
        dbapass=$1
        ;;
     -instance)
        shift
        instance=$1
        ;;
     -bingoname)
        shift
        bingoname=$1
        ;;
     -bingopass)
        shift
        bingopass=$1
        ;;
     -mode)
        shift
        mode=$1
        ;;
     -oracleusername)
        shift
        oracle_username=$1
        ;;
     -oracleauthtoken)
        shift
        oracle_auth_token=$1
        ;;
     -walleturi)
        shift
        wallet_uri=$1
        ;;
     -walletdir)
        shift
        tns_admin=$1
        ;;
     -listenerurl)
        shift
        listener_url=$1
        ;;
     -listenerhostname)
        shift
        listener_hostname=$1
        ;;
     -y)
        y=1
        ;;
     *)
        echo "Unknown parameter: $1";
        usage;
        exit -1
  esac
  shift
done

echo "Target directory  : $libdir";
echo "DBA name          : $dbaname";
if [ ! "$dbapass" = "" ]; then
  echo "DBA password      : $dbapass";
fi
if [ ! "$instance" = "" ]; then
  echo "Oracle instance   : $instance";
else
  echo "Oracle instance   : <default>";
fi
echo "Bingo name        : $bingoname";
echo "Bingo password    : $bingopass";

if [ "$y" != "1" ]; then
  echo "Proceed (y/N)?"
  read proceed

  if [ "$proceed" != "y" ] && [ "$proceed" != "Y" ]; then
    echo 'Aborting';
    exit 0;
  fi
fi

if [ ! "$instance" = "" ]; then
  instance=@$instance
fi

mkdir -p $libdir

if [ "$mode" != "autonomous" ]; then
  echo set verify off >sql/bingo/bingo_lib.sql 
  echo spool bingo_lib\; >>sql/bingo/bingo_lib.sql 
  echo create or replace LIBRARY bingolib AS \'$libdir/libbingo-oracle$libext\' >>sql/bingo/bingo_lib.sql 
  echo / >>sql/bingo/bingo_lib.sql 
  echo spool off\; >>sql/bingo/bingo_lib.sql 

  cp lib/libbingo-oracle$libext $libdir
  if [ $? != 0 ]; then
    echo 'Cannot copy libbingo-oracle'$libext' to '$libdir
    exit
  fi
fi


cd sql/system
if [ "$dbapass" = "" ]; then
  sqlplus $dbaname$instance @bingo_init.sql $bingoname $bingopass
elif [ "$mode" = "autonomous" ]; then
  echo "Oracle Autonomous Database detected, using autonomous init script."
  export TNS_ADMIN=/home/opc/wallet
  sqlplus $dbaname/$dbapass$instance @bingo_oracle_autonomous_init.sql $bingoname $bingopass $oracle_username $oracle_auth_token $wallet_uri $listener_url $listener_hostname
else
  sqlplus $dbaname/$dbapass$instance @bingo_init.sql $bingoname $bingopass
fi

cd ../bingo
if [ "$mode" = "autonomous" ]; then
  echo "Executing makebingo_autonomous.sql"
  sqlplus $bingoname/$bingopass$instance @makebingo_autonomous.sql
else
  sqlplus $bingoname/$bingopass$instance @makebingo.sql
fi
sqlplus $bingoname/$bingopass$instance @bingo_config.sql
cd ..
sqlplus $bingoname/$bingopass$instance @dbcheck.sql
cd ..