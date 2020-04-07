#!/usr/bin/env bash
set -e
source /assets/colorecho

trap "echo_red '******* ERROR: Something went wrong.'; exit 1" SIGTERM
trap "echo_red '******* Caught SIGINT signal. Stopping...'; exit 2" SIGINT

if [ ! -d "/install/database" ]; then
	echo_red "Installation files not found. Unzip installation files into mounted(/install) folder"
	exit 1
fi

if [ ! -e "$SELECTED_LANGUAGES" ]; then
	sed -i -e "s/SELECTED_LANGUAGES=en,zh_CN/SELECTED_LANGUAGES=${SELECTED_LANGUAGES}/g" \
		/assets/db_install.rsp
fi

if [ ! -e "$ORACLE_EDITION" ]; then
	sed -i -e "s/oracle.install.db.InstallEdition=EE/oracle.install.db.InstallEdition=${ORACLE_EDITION}/g" \
		/assets/db_install.rsp
fi

echo_yellow "Installing Oracle Database 11g"
su oracle -c "/install/database/runInstaller -silent -force -ignoresysprereqs -ignorePrereq -waitforcompletion -responseFile /assets/db_install.rsp"
/opt/oracle/oraInventory/orainstRoot.sh
/opt/oracle/app/product/11.2.0/dbhome_1/root.sh

# apply patch if available
if [ -d /install/OPatch ]; then
	chown -R oracle:oinstall /install/OPatch

	if [ -d /install/db_patch ]; then
		chown -R oracle:oinstall /install/db_patch
	fi

	if [ -d /install/ojvm_patch ]; then
		chown -R oracle:oinstall /install/ojvm_patch
	fi

	su oracle -c "/assets/patch.sh"
fi

# cleanup everything
su oracle -c "/assets/cleanup.sh"
