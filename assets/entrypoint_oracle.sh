#!/usr/bin/env bash

# fix env
export HOME=/opt/oracle
export USER=oracle
export LOGNAME=$USER
export USERNAME=$USER

set -e
source /assets/colorecho
source ~/.bashrc

alert_log="$ORACLE_BASE/diag/rdbms/${DB_GDBNAME:-orcl}/$ORACLE_SID/trace/alert_$ORACLE_SID.log"
listener_log="$ORACLE_BASE/diag/tnslsnr/$HOSTNAME/listener/trace/listener.log"
pfile=$ORACLE_HOME/dbs/init$ORACLE_SID.ora
monitor_pid=""

# monitor $logfile
monitor() {
	tail --pid $$ -F -n 0 $1 | while read line; do echo -e "$2: $line"; done &
	monitor_pid=$(jobs -p)
}


trap_db() {
	trap "echo_red 'Caught SIGTERM signal, shutting down...'; stop" SIGTERM;
	trap "echo_red 'Caught SIGINT signal, shutting down...'; stop" SIGINT;
}

start_db() {
	echo_yellow "Starting listener..."
	monitor $listener_log listener
	MON_LSNR_PID=$monitor_pid
	lsnrctl start | while read line; do echo -e "lsnrctl: $line"; done
	echo_yellow "Starting database..."
	trap_db
	monitor $alert_log alertlog
	MON_ALERT_PID=$monitor_pid
	sqlplus / as sysdba <<-EOF |
		pro Starting with pfile='$pfile' ...
		startup;
		alter system register;
		exit 0
	EOF
	while read line; do echo -e "sqlplus: $line"; done
	# user script
	/assets/run_user_scripts.sh /opt/oracle/user_scripts/7-after-db-startup
	# end user script
	echo_green "Database started."
	wait $MON_ALERT_PID
}

create_db_apply_env() {

	if [ ! -z "${DB_SYSPASSWORD}" ]; then
		sed -i "/SYSPASSWORD = /c\\SYSPASSWORD = \"${DB_SYSPASSWORD}\"\\" /assets/dbca.rsp
	fi

	if [ ! -z "${DB_GDBNAME}" ]; then
		sed -i "/GDBNAME = /c\\GDBNAME = \"${DB_GDBNAME}\"\\" /assets/dbca.rsp
	fi

	if [ ! -z "${DB_SYSTEMPASSWORD}" ]; then
		sed -i "/SYSTEMPASSWORD = /c\\SYSTEMPASSWORD = \"${DB_SYSTEMPASSWORD}\"\\" /assets/dbca.rsp
	fi

	if [ ! -z "${DB_CHARACTERSET}" ]; then
		sed -i "/CHARACTERSET=/c\\CHARACTERSET=\"${DB_CHARACTERSET}\"\\" /assets/dbca.rsp
	fi

	if [ ! -z "${DB_TOTALMEMORY}" ]; then
		sed -i "/TOTALMEMORY=/c\\TOTALMEMORY=\"${DB_TOTALMEMORY}\"\\" /assets/dbca.rsp
	fi

	if [ ! -z "${DB_INITPARAMS}" ]; then
		sed -i "/INITPARAMS=/c\\INITPARAMS=\"${DB_INITPARAMS}\"\\" /assets/dbca.rsp
	fi

}

create_db() {
	echo_yellow "Database does not exist. Creating database..."
	date "+%F %T"
	create_db_apply_env
	monitor $alert_log alertlog
	MON_ALERT_PID=$monitor_pid
	monitor $listener_log listener
	MON_LSNR_PID=$monitor_pid
	echo_green "START DBCA"
	dbca -silent -createDatabase -responseFile /assets/dbca.rsp ||
		cat $ORACLE_HOME/cfgtoollogs/dbca/${DB_GDBNAME}/${DB_GDBNAME}.log ||
		cat $ORACLE_HOME/cfgtoollogs/dbca/${DB_GDBNAME}.log
	echo_green "Database created."
	date "+%F %T"
	change_dpdump_dir
	set_db_config
	touch $pfile
	trap_db
	kill $MON_ALERT_PID $MON_LSNR_PID
	#wait $MON_ALERT_PID
}

stop() {
	trap '' SIGINT SIGTERM
	stop_db
	echo_yellow "Shutting down listener..."
	lsnrctl stop | while read line; do echo -e "lsnrctl: $line"; done
	kill $MON_ALERT_PID $MON_LSNR_PID
	exit 0
}

stop_db() {
	ps -ef | grep ora_pmon | grep -v grep > /dev/null && \
	echo_yellow "Shutting down the database..." && \
	sqlplus / as sysdba <<-EOF |
		set echo on
		shutdown immediate;
		exit 0
	EOF
	while read line; do echo -e "sqlplus: $line"; done
}

change_dpdump_dir () {
	echo_green "Changind dpdump dir to $ORACLE_BASE/oradata/dpdump"
	sqlplus / as sysdba <<-EOF |
		create or replace directory data_pump_dir as '$ORACLE_BASE/oradata/dpdump';
		commit;
		exit 0
	EOF
	while read line; do echo -e "sqlplus: $line"; done
}


set_db_config () {
	echo_green "Standardize the creation of the database."
	sqlplus / as sysdba <<-EOF |
		EXEC DBMS_STATS.SET_GLOBAL_PREFS('CONCURRENT','FALSE');
		alter profile default limit PASSWORD_LIFE_TIME unlimited;
		commit;
		exit 0
	EOF
	while read line; do echo -e "sqlplus: $line"; done
}

link_db_files () {
	echo_green "Creating link of the database files."
	if [ ! -L $ORACLE_HOME/dbs ]; then
		if [ ! -d $ORACLE_HOME ]; then
			mkdir -p $ORACLE_HOME
		fi
		if [ ! -d $ORACLE_BASE/oradata/dbs ]; then
			mkdir -p $ORACLE_BASE/oradata/dbs
		fi
		if [ -d $ORACLE_HOME/dbs ]; then
			mv -f $ORACLE_HOME/dbs/* $ORACLE_BASE/oradata/dbs
			rmdir $ORACLE_HOME/dbs
		fi
		ln -fsT $ORACLE_BASE/oradata/dbs $ORACLE_HOME/dbs
	fi

	if [ ! -L $ORACLE_BASE/admin ]; then
		if [ ! -d $ORACLE_BASE/admin ]; then
			mkdir -p $ORACLE_BASE/admin
		fi
		if [ ! -d $ORACLE_BASE/oradata/admin ]; then
			mkdir -p $ORACLE_BASE/oradata/admin
		fi
		if [ -d $ORACLE_BASE/admin ]; then
			if [ -n "$(ls -A "${ORACLE_BASE}/admin")" ]; then
				mv -f $ORACLE_BASE/admin/* $ORACLE_BASE/oradata/admin/
			fi
			rmdir $ORACLE_BASE/admin
		fi
		ln -fsT $ORACLE_BASE/oradata/admin $ORACLE_BASE/admin
	fi

	if [ ! -d $ORACLE_BASE/diag/rdbms/${DB_GDBNAME:-orcl}/$ORACLE_SID/trace ]; then
		mkdir -p $ORACLE_BASE/diag/rdbms/${DB_GDBNAME:-orcl}/$ORACLE_SID/trace
	fi
	if [ ! -d $ORACLE_BASE/admin/${DB_GDBNAME:-orcl}/adump ]; then
		mkdir -p $ORACLE_BASE/admin/${DB_GDBNAME:-orcl}/adump
	fi
	if [ ! -d $ORACLE_BASE/admin/$ORACLE_SID/adump ]; then
		mkdir -p $ORACLE_BASE/admin/$ORACLE_SID/adump
	fi
	if [ ! -d $ORACLE_BASE/diag/tnslsnr/$HOSTNAME/listener/trace ]; then
		mkdir -p $ORACLE_BASE/diag/tnslsnr/$HOSTNAME/listener/trace
	fi
	if [ ! -f $alert_log ]; then
		touch $alert_log
	fi
	if [ ! -f $listener_log ]; then
		touch $listener_log
	fi
}

echo "Checking shared memory..."
df -h | grep "Mounted on" && df -h | egrep --color "^.*/dev/shm" || echo "Shared memory is not mounted."
link_db_files
if [ ! -f $pfile ]; then
	# user script
	/assets/run_user_scripts.sh /opt/oracle/user_scripts/3-before-db-create ONCE
	# end user script
	mkdir -p $ORACLE_BASE/oradata/flash_recovery_area
	mkdir -p $ORACLE_BASE/oradata/dpdump
	create_db;
	# user script
	/assets/run_user_scripts.sh /opt/oracle/user_scripts/4-after-db-create ONCE
	# end user script
fi
chmod 777 $ORACLE_BASE/oradata/dpdump
# user script
/assets/run_user_scripts.sh /opt/oracle/user_scripts/6-before-db-startup
# end user script
start_db

