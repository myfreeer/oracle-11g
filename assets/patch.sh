#!/usr/bin/env bash
set -e
source /assets/colorecho
source ~/.bashrc

if [ ! -d /install/OPatch ]; then
	echo_yellow "OPatch not found, skip patch."
	exit 0
fi

echo_green "Installing OPatch."
# remove original OPatch
rm -rf ${ORACLE_HOME}/OPatch
cp -R /install/OPatch ${ORACLE_HOME}/

if [ -d /install/db_patch ]; then
	echo_green "Installing database patch."
	pushd /install/db_patch/*
	${ORACLE_HOME}/OPatch/opatch apply -silent -ocmrf /assets/ocm.rsp
	popd
fi

if [ -d /install/ojvm_patch ]; then
	echo_green "Installing OJVM patch."
	pushd /install/ojvm_patch/*
	${ORACLE_HOME}/OPatch/opatch apply -silent -ocmrf /assets/ocm.rsp
	popd
fi
