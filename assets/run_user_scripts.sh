#!/usr/bin/env bash

source /assets/colorecho
source ~/.bashrc

SCRIPT_ROOT="$1"
ONCE_ONLY="$2"
SHELL_ONLY="$2"
CURRENT_USER=$(whoami)

function run_shell_script() {
    local exec_date=$(date +%Y-%m-%d_%H-%M-%S_%N)
    local script="$1"
    local script_name="${script%.*}"
    local stdout_log="${script_name}_sh_${exec_date}.out.log"
    local stderr_log="${script_name}_sh_${exec_date}.err.log"
    echo_green "Running user script ${script}"
    # https://stackoverflow.com/a/692407
    . "$script" > >(tee -a "${stdout_log}") 2> >(tee -a "${stderr_log}" >&2)
    if [ ! -z "$ONCE_ONLY" ]; then
        mv -f "${script}" "${script_name}.sh_done"
    fi
}

function run_sql_plus_script() {
    if [ "${CURRENT_USER}" != "oracle" ]; then
        return;
    fi
    if [ ! -z "$SHELL_ONLY" ]; then
        return;
    fi
    local exec_date=$(date +%Y-%m-%d_%H-%M-%S_%N)
    local script="$1"
    local script_name="${script%.*}"
    local stdout_log="${script_name}_sql_${exec_date}.out.log"
    local stderr_log="${script_name}_sql_${exec_date}.err.log"
    echo_green "Running user sql script ${script}"
    # https://github.com/pavlobornia/oracle-11g/blob/master/assets/runUserScripts.sh
    echo "exit" | sqlplus -s "/ as sysdba" @"$script" > >(tee -a "${stdout_log}") 2> >(tee -a "${stderr_log}" >&2)
    if [ ! -z "$ONCE_ONLY" ]; then
        mv -f "${script}" "${script_name}.sql_done"
    fi
}


# Check whether parameter has been passed on
if [ -z "${SCRIPT_ROOT}" ]; then
   echo_yellow "$0: No SCRIPT_ROOT passed on, no scripts will be run";
   exit 1;
fi;

# Execute custom provided files (only if directory exists and has files in it)
if [ -d "${SCRIPT_ROOT}" ] && [ -n "$(ls -A "${SCRIPT_ROOT}")" ]; then
    echo_green "Executing user defined scripts in ${SCRIPT_ROOT} ad ${CURRENT_USER}"
    pushd "${SCRIPT_ROOT}"

    for f in $SCRIPT_ROOT/*; do
        case "$f" in
            *.sh)     run_shell_script     "$f" ;;
            *.sql)    run_sql_plus_script  "$f" ;;
            *)        echo_yellow "Ignoring $f" ;;
        esac
    done

    popd
    echo_green "DONE: Executing user defined scripts in ${SCRIPT_ROOT}"
fi;
