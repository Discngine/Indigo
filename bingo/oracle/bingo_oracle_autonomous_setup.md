# Bingo Integration with Oracle Autonomous Database (Oracle Cloud)

This guide is intended for users who want to deploy and use the **Bingo cartridge** with **Oracle Autonomous Databases** on **Oracle Cloud Infrastructure (OCI)**.

Because Autonomous Database restricts access to the underlying operating system, native shared libraries (such as `.so` files) required by Bingo cannot be loaded directly. This document describes how to enable Bingo functionality by hosting the required shared library externally and connecting to it from the database.

## Prerequisites

The `.so` library must be hosted externally as a microservice that the database can invoke on demand. There are two supported approaches:

- **Oracle Marketplace solution** — See the [official documentation](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/user-defined-functions-external.html) for details.
- **Docker container (recommended and tested)** — Host the library within a container.

### Setting up the external procedure service (Docker method)

This documentation demonstrate the hosting of the Docker container on an **OCI Compute instance**. This approach provides flexibility, full control over the container environment, and straightforward networking configuration between the Autonomous Database and the external service.

However, it is also possible to host the external procedure container using other OCI services that support containerized workloads, such as:
- **OCI Container Instances** — a managed serverless container runtime.
- **OCI Container Engine for Kubernetes (OKE)** — a managed Kubernetes service.
- **OCI Functions** — for advanced users who may wish to refactor the shared library into a function (requires additional adaptation beyond the scope of this document).

Regardless of the hosting method, the key requirement is that the container service must:
- Expose the external procedure endpoint on a network accessible to the Autonomous Database.
- Allow secure communication (e.g., via VCN peering or private endpoints).

To set up the Docker-based service on OCI Compute:

1. Refer to the [Oracle ADB extproc repository](https://github.com/oracle/adb-extproc/pkgs/container/adb-extproc).
2. Download the Bingo package and locate the required `.so` library.
3. Start the container:

    ```bash
    docker run -d -p 16000:16000 \
      -e EXTPROC_WALLET_PASSWORD='Welcome1' \
      -e EXTPROC_DLLS='/u01/app/oracle/extproc_libs/extprocutils.so' \
      -v <path_to_libbingo.so>:/u01/app/oracle/extproc_libs/extprocutils.so \
      --network=host \
      --name extproc \
      ghcr.io/oracle/adb-extproc:latest
    ```

4. Ensure that network traffic is permitted between the Autonomous Database and the Compute instance (or chosen hosting service) on the configured port.
5. Verify that the `.so` file is correctly mounted within the container.
6. Retrieve the wallet file required by the external procedure:

    ```bash
    docker cp extproc:/u01/app/oracle/wallets/extproc_wallet/cwallet.sso .
    ```

7. Upload the `cwallet.sso` file to a secure location, such as an S3 bucket.

## Installing Bingo

Once the external procedure service is operational, proceed with the installation of the Bingo cartridge:

1. Download the Autonomous Database wallet using the web console or Oracle Cloud CLI:

    ```bash
    oci db autonomous-database generate-wallet \
      --autonomous-database-id <ocid> \
      --file wallet.zip \
      --password <wallet_password>
    ```

2. Extract the wallet archive:

    ```bash
    unzip wallet.zip
    ```

3. Run the Bingo installation script. When installing on Oracle Autonomous Database, additional parameters are required:

    ```bash
    ./bingo-oracle-install.sh \
      -dbaname <db_user> \
      -dbapass <db_password> \
      -instance <service_profile> \
      -bingoname bingo \
      -bingopass <bingo_password> \
      -db_type oracle_autonomous_database \
      -oracleusername <oracle_cloud_username> \
      -oracleauthtoken <auth_token> \
      -walleturi <url_to_cwallet.sso> \
      -walletdir <path_to_extracted_wallet> \
      -listenerurl <container_service_url> \
      -listenerhostname <host_vm_name>
    ```

Upon successful installation, you can validate the setup using standard Bingo test queries.

## Notes

- Ensure that all network and security configurations comply with your organization’s policies and best practices.
- The instructions assume familiarity with Docker, Oracle Cloud Infrastructure CLI, and Oracle Autonomous Database administration.
