#!/usr/bin/env bash

set -e
source /assets/colorecho
nohup /usr/sbin/sshd -D  2> /dev/null &

export TZ=${TZ:-'Asia/Shanghai'}

ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime
if [ ! -d "/opt/oracle/app/product/11.2.0/dbhome_1" ]; then
	echo_yellow "Database is not installed. Installing..."
	# user script
	/assets/run_user_scripts.sh /opt/oracle/user_scripts/1-before-db-install ONCE SHELL_ONLY
	# end user script
	/assets/install.sh
	# user script
	/assets/run_user_scripts.sh /opt/oracle/user_scripts/2-after-db-install ONCE SHELL_ONLY
	# end user script
	echo_yellow "Database installation complete."
	echo_yellow "Commit the image if needed."
	echo_yellow "Restart the container to configure and start db."
	exit 0
fi

if [ ! -z "${DB_SID}" ]; then
	sed -i "/ORACLE_SID/c\\export ORACLE_SID=${DB_SID}\\" ~oracle/.bashrc
	sed -i "/SID = /c\\SID = \"${DB_SID}\"\\" /assets/dbca.rsp
fi

if [ -d opt/oracle/app/oradata ]; then
	chown -R oracle:oinstall /opt/oracle/app/oradata
fi

if [ -d /opt/oracle/user_scripts ]; then
	chown -R oracle:oinstall /opt/oracle/user_scripts
fi

# entrypoint_oracle would handle singals
exec /assets/gosu oracle "/assets/entrypoint_oracle.sh"
