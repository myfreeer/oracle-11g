Image for running Oracle Database 11g Standard/Enterprise.
Due to oracle license restrictions image is not contain database itself and will install it on first run from external directory.

``This image for development use only``

# Usage
Download database installation files from [Oracle site](http://www.oracle.com/technetwork/database/in-memory/downloads/index.html) and unpack them to **install_folder**.

## Prepare db and patch files
Do this in host, avoiding useless files in image.

### Prepare host os
```sh
# install unzip in host if needed
yum install -y unzip
# change this to your dir contains install packages
export INSTALL_DIR=/root/install
```

### Prepare db install files
```sh
pushd $INSTALL_DIR
# oracle database 11.2.0.4 part 1
unzip p13390677_112040_Linux-x86-64_1of7.zip
# oracle database 11.2.0.4 part 2
unzip p13390677_112040_Linux-x86-64_2of7.zip
popd
```

### (Optional) Prepare db patch files
Warning: currently running dbca with ojvm patch in container
is extremely slow with amounts of warnings and errors
and would probably stuck at 73%.
Use it on your own risk or just skip that.

```sh
pushd $INSTALL_DIR

# OPatch 11.2.0.3.20 or later
unzip p6880880_112000_Linux-x86-64.zip

mkdir db_patch
cd db_patch
# DATABASE PATCH SET UPDATE 11.2.0.4.190716
unzip ../p29497421_112040_Linux-x86-64.zip 
cd ..

mkdir ojvm_patch
cd ojvm_patch
# OJVM PATCH SET UPDATE 11.2.0.4.190716
unzip ../p29610422_112040_Linux-x86-64.zip 
cd ..

popd
```

## Build the image
Run container and it will install oracle and create database:

```sh
# change this to the INSTALL_DIR in prev step
export INSTALL_DIR=/root/install
# build installer image
docker build . -t oracle-db:11.2.0.4-not-installed

# run installer
docker run -it --name oracle11g-installer -p 1521:1521 -p 1522:22 -v $INSTALL_DIR:/install oracle-db:11.2.0.4-not-installed

#commit this container
docker commit oracle11g-installer oracle-db:11.2.0.4

# Save image for offline use
# docker save oracle-db > oracle-db_11.2.0.4_docker.tar

# Drop the installer container
docker rm oracle11g-installer
```

## Configure and run database
### Configure and run database in container

```sh
# Configure and start db in non-privileged mode
# and manally stop it after fully configured
docker run -it --name oracle11g -p 1521:1521 -p 1522:22 oracle-db:11.2.0.4
# Make a normal start
docker start oracle11g
# Watch the logs
# docker logs -f oracle11g
# Configure db container auto atart
docker update --restart=unless-stopped oracle11g
```

### Configure and run database with database files mounted to host

```sh
# Create mount dir
export DB_FILES_MOUNT_DIR=/root/db-dir
mkdir -p -m 777 $DB_FILES_MOUNT_DIR
# Configure and start db in non-privileged mode
# and manally stop it after fully configured
docker run -it --name oracle11g -p 1521:1521 -p 1522:22 -v $DB_FILES_MOUNT_DIR:/opt/oracle/app/oradata oracle-db:11.2.0.4
# Make a normal start
docker start oracle11g
# Watch the logs
# docker logs -f oracle11g
# Configure db container auto atart
docker update --restart=unless-stopped oracle11g
```

## Other info
Database located in **/opt/oracle** folder

* OS users:
    * root/123456
    * oracle/123456
* DB users:
    * SYS/123456
    * SYSTEM/123456
* SSH port: `22`
* Oracle port: `1521`
* Sid: `orcl`

Optionally you can map dpdump folder to easy upload dumps:
```sh
docker run -it --privileged --name oracle11g -p 1521:1521 -p 1522:22 -v <local_dpdump>:/opt/oracle/app/oradata/dpdump oracle-db:11.2.0.4
```
To execute impdp/expdp just use docker exec command:
```sh
docker exec -it oracle11g impdp ..
```

### User scripts
A user script is either a shell script (`*.sh`)
or a sql plus script (`*.sql`) provided by user
mounted into some certain folder of the container,
which should be executed in the container by:
* shell script
    * `root` user
    * `oracle` user
* sql plus script
   * `sys` as sysdba

A user script should be executed at:
* once before database installation
    * path: `/opt/oracle/user_scripts/1-before-db-install`
    * target: shell script
    * user: `root`
* once after database installation
    * path: `/opt/oracle/user_scripts/2-after-db-install`
    * target: shell script
    * user: `root`
* once before database creation
    * path: `/opt/oracle/user_scripts/3-before-db-create`
    * target: shell script and sql script
    * user: `oracle` for shell script and `sys` for sql script
* once after database creation before database startup
    * path: `/opt/oracle/user_scripts/4-after-db-create`
    * target: shell script and sql script
    * user: `oracle` for shell script and `sys` for sql script
* every time container starts up before database startup
    * path: `/opt/oracle/user_scripts/5-before-db-startup`
    * target: shell script and sql script
    * user: `oracle` for shell script and `sys` for sql script
* every time container starts up after database startup as `oracle`
    * path: `/opt/oracle/user_scripts/6-after-db-startup`
    * target: shell script and sql script
    * user: `oracle` for shell script and `sys` for sql script

A user script that should be executed once should be renamed
to mark being executed to avoid multiple execution after executed.

Execution output (stdout and stderr) of a user script 
should be collected to the folder of the user script 
with the filename of the user script, 
plus script execution timestamp in format of
`date +%Y-%m-%d_%H-%M-%S_%N`.
