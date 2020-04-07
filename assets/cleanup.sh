#!/usr/bin/env bash
set -e
source /assets/colorecho
source ~/.bashrc

# Remove not needed components
rm -rf ${ORACLE_HOME}/apex               # APEX
rm -rf ${ORACLE_HOME}/ords               # ORDS
rm -rf ${ORACLE_HOME}/sqldeveloper       # SQL Developer
rm -rf ${ORACLE_HOME}/inventory/backup/* # OUI backup
rm -rf ${ORACLE_HOME}/network/tools/help # Network tools help
rm -rf ${ORACLE_HOME}/assistants/dbua    # Database upgrade assistant
rm -rf ${ORACLE_HOME}/dmu                # Database migration assistant
rm -rf ${ORACLE_HOME}/install/pilot      # Remove pilot workflow installer
rm -rf ${ORACLE_HOME}/suptools           # Support tools
rm -rf ${ORACLE_HOME}/ucp                # UCP connection pool
rm -rf ${ORACLE_HOME}/lib/*.zip          # All installer files

# Temp locations
rm -rf /tmp/*.rsp
rm -rf /tmp/InstallActions*
rm -rf /tmp/CVU*oracle

find ${ORACLE_INVENTORY} -type f -name -delete *.log
find ${ORACLE_BASE}/product -type f -name -delete *.log

rm -rf ${ORACLE_HOME}/inventory # remove inventory
# keep oui, or there would be NoClassDefFoundError: oracle/sysman/oii/oiil/OiilNativeException
# rm -rf ${ORACLE_HOME}/oui
rm -rf ${ORACLE_HOME}/OPatch # remove OPatch
rm -rf /tmp/OraInstall*
rm -rf ${ORACLE_HOME}/.patch_storage # remove patch storage
