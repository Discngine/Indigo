# Bingo Oracle Autonomous database

Since we don't have access to the underlying system of this type of database we can't import the .so lib which is usually used by the bingo cartridge. This document describes how with an external procedure use bingo on this type of database.

## Prerequisites

We are going to host the .so file as an external microservice which will be queried on each bingo request. There is two methods to host this external file : Using the Oracle marketplace described [here](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/user-defined-functions-external.html) and using a docker container which is the method we tested.

Refer to this [repo](https://github.com/oracle/adb-extproc/pkgs/container/adb-extproc). Download bingo and locate this .so file. Then start the container: 

```
sudo docker run -d -p 16000:16000 -e EXTPROC_WALLET_PASSWORD='Welcome1'   -e EXTPROC_DLLS='/u01/app/oracle/extproc_libs/extprocutils.so'   -v <path_to_libbingo.so>:/u01/app/oracle/extproc_libs/extprocutils.so   --network=host   --name extproc   ghcr.io/oracle/adb-extproc:latest
```

As you can see you are gonna need to open the traffic between the database and the vm where the container is running on the specific port you choose at the container start. Then enter in the container and check in the path that the .so file is well mounted.

Then we need to get the `cwallet.sso` file. Run:

`docker cp extproc:/u01/app/oracle/wallets/extproc_wallet/cwallet.sso .`

Finally upload the file to an s3 bucket.

## Bingo install

The external procedure is running, we can now install bingo. Download the wallet from the database. You can use the UI or the CLI like this :

```
oci db autonomous-database generate-wallet   --autonomous-database-id <ocid>   --file wallet.zip   --password <db_password>
```

Unzip the wallet.

To install bingo use the same way as usual : the `bingo-oracle-install.sh` file. Additional parameters have been added to handle autonomous database. Here is how to install the cartridge:

```
./bingo-oracle-install.sh -dbaname <db_user> -dbapass <db_password> -instance <service_profile> -bingoname bingo -bingopass <bingo_password> -mode autonomous -oracleusername <your_oracle_username> -oracleauthtoken <an_auth_token_you_own> -walleturi <url_of_the_cwallet.sso> -walletdir <dir_where_you_unzip_wallet.zip> -listenerurl <url_of_the_container> -listenerhostname <hostname_of_the_vm_hosting_container>
```

Bingo should be installed now. Then you can test it using the same commands as usual.


