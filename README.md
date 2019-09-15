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

## Build the image
Run container and it will install oracle and create database:

```sh
# change this to the INSTALL_DIR in prev step
export INSTALL_DIR=/root/install
# build installer image
docker build . -t oracle-db:11.2.0.4-not-installed

# run installer
docker run -it --privileged --name oracle11g-installer -p 1521:1521 -p 1522:22 -v $INSTALL_DIR:/install oracle-db:11.2.0.4-not-installed

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
