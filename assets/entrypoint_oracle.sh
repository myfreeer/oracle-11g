#!/usr/bin/env bash

set -e
source /assets/colorecho
source ~/.bashrc

alert_log="$ORACLE_BASE/diag/rdbms/$ORACLE_SID/$ORACLE_SID/trace/alert_$ORACLE_SID.log"
listener_log="$ORACLE_BASE/diag/tnslsnr/$HOSTNAME/listener/trace/listener.log"
pfile=$ORACLE_HOME/dbs/init$ORACLE_SID.ora

# monitor $logfile
monitor() {
    tail --pid $$ -F -n 0 $1 | while read line; do echo -e "$2: $line"; done
}


trap_db() {
	trap "echo_red 'Caught SIGTERM signal, shutting down...'; stop" SIGTERM;
	trap "echo_red 'Caught SIGINT signal, shutting down...'; stop" SIGINT;
}

start_db() {
	echo_yellow "Starting listener..."
	monitor $listener_log listener &
	lsnrctl start | while read line; do echo -e "lsnrctl: $line"; done
	MON_LSNR_PID=$!
	echo_yellow "Starting database..."
	trap_db
	monitor $alert_log alertlog &
	MON_ALERT_PID=$!
	sqlplus / as sysdba <<-EOF |
		pro Starting with pfile='$pfile' ...
		startup;
		alter system register;
		exit 0
	EOF
	while read line; do echo -e "sqlplus: $line"; done
	wait $MON_ALERT_PID
}

create_db() {
	echo_yellow "Database does not exist. Creating database..."
	date "+%F %T"
	monitor $alert_log alertlog &
	MON_ALERT_PID=$!
	monitor $listener_log listener &
	#lsnrctl start | while read line; do echo -e "lsnrctl: $line"; done
	MON_LSNR_PID=$!
    echo "START DBCA"
	dbca -silent -createDatabase -responseFile /assets/dbca.rsp ||
		cat $ORACLE_BASE/cfgtoollogs/dbca/$ORACLE_SID/$ORACLE_SID.log ||
		cat $ORACLE_BASE/cfgtoollogs/dbca/$ORACLE_SID.log
	echo_green "Database created."
	date "+%F %T"
	change_dpdump_dir
	set_db_config
    touch $pfile
	trap_db
    kill $MON_ALERT_PID
    kill $MON_LSNR_PID
	#wait $MON_ALERT_PID
}

stop() {
    trap '' SIGINT SIGTERM
	shu_immediate
	echo_yellow "Shutting down listener..."
	lsnrctl stop | while read line; do echo -e "lsnrctl: $line"; done
	kill $MON_ALERT_PID $MON_LSNR_PID
	exit 0
}

shu_immediate() {
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
	if [ ! -L $ORACLE_BASE/product/11.2.0/dbhome_1/dbs ]; then
		if [ ! -d $ORACLE_BASE/product/11.2.0/dbhome_1 ]; then
			mkdir -p $ORACLE_BASE/product/11.2.0/dbhome_1
		fi
		if [ ! -d $ORACLE_BASE/oradata/dbs ]; then
			mkdir -p $ORACLE_BASE/oradata/dbs
		fi
		if [ -d $ORACLE_BASE/product/11.2.0/dbhome_1/dbs ]; then
			mv -f $ORACLE_BASE/product/11.2.0/dbhome_1/dbs/* $ORACLE_BASE/oradata/dbs
			rmdir $ORACLE_BASE/product/11.2.0/dbhome_1/dbs
		fi
		ln -fsT $ORACLE_BASE/oradata/dbs $ORACLE_BASE/product/11.2.0/dbhome_1/dbs
	fi
	
	if [ ! -L $ORACLE_BASE/admin/$ORACLE_SID/pfile ]; then
		if [ ! -d $ORACLE_BASE/admin/$ORACLE_SID ]; then
			mkdir -p $ORACLE_BASE/admin/$ORACLE_SID
		fi
		if [ ! -d $ORACLE_BASE/oradata/pfile ]; then
			mkdir -p $ORACLE_BASE/oradata/pfile
		fi
		if [ -d $ORACLE_BASE/admin/$ORACLE_SID/pfile ]; then
			mv -f $ORACLE_BASE/admin/$ORACLE_SID/pfile/* $ORACLE_BASE/oradata/pfile/
			rmdir $ORACLE_BASE/admin/$ORACLE_SID/pfile
		fi
		ln -fsT $ORACLE_BASE/oradata/pfile $ORACLE_BASE/admin/$ORACLE_SID/pfile
	fi
	if [ ! -d $ORACLE_BASE/diag/rdbms/$ORACLE_SID/$ORACLE_SID/trace ]; then
		mkdir -p $ORACLE_BASE/diag/rdbms/$ORACLE_SID/$ORACLE_SID/trace
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
  mkdir -p $ORACLE_BASE/oradata/flash_recovery_area
  mkdir -p $ORACLE_BASE/oradata/dpdump
  create_db;
fi
chmod 777 $ORACLE_BASE/oradata/dpdump
start_db
