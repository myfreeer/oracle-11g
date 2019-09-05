Image for running Oracle Database 11g Standard/Enterprise. Due to oracle license restrictions image is not contain database itself and will install it on first run from external directory.

``This image for development use only``

# Usage
Download database installation files from [Oracle site](http://www.oracle.com/technetwork/database/in-memory/downloads/index.html) and unpack them to **install_folder**.
Run container and it will install oracle and create database:

```sh
docker build . -t oracle-db:11.2.0.4-not-installed
docker run -it --privileged --name oracle11g -p 1521:1521 -p 1522:22 -v <install_folder>:/install oracle-db:11.2.0.4-not-installed
```
Then you can commit this container to have installed and configured oracle database:
```sh
#commit this container
docker commit oracle11g oracle-db:11.2.0.4
# Save image for offline use
# docker save oracle-db > oracle-db_11.2.0.4_docker.tar
# Drop the installer container
docker rm oracle11g
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

Database located in **/opt/oracle** folder

OS users:
* root/123456
* oracle/123456

DB users:
* SYS/123456
* SYSTEM/123456

Optionally you can map dpdump folder to easy upload dumps:
```sh
docker run -it --privileged --name oracle11g -p 1521:1521 -p 1522:22 -v <local_dpdump>:/opt/oracle/dpdump oracle-db:11.2.0.4
```
To execute impdp/expdp just use docker exec command:
```sh
docker exec -it oracle11g impdp ..
```
