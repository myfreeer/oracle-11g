FROM centos:7

ADD assets /assets

# build-time args
ARG TINI_VERSION=v0.18.0
ARG GOSU_VERSION=1.11
ARG SYS_ROOT_PWD=123456
ARG SYS_ORACLE_PWD=123456
RUN chmod -R 755 /assets && /assets/setup.sh

ENV TZ="Asia/Shanghai" \
    SELECTED_LANGUAGES="en,zh_CN" \
    ORACLE_EDITION="EE" \
    DB_SID="orcl" \
    DB_SYSPASSWORD="123456" \
    DB_SYSTEMPASSWORD="123456" \
    DB_CHARACTERSET="AL32UTF8" \
    DB_TOTALMEMORY="350" \
    DB_INITPARAMS="memory_target=0,sga_target=280,pga_aggregate_target=40,db_recovery_file_dest=/opt/oracle/app/oradata/fast_recovery_area,audit_trail=none,audit_sys_operations=false,filesystemio_options=directio,standby_file_management=auto,java_jit_enabled=false"

VOLUME ["/opt/oracle/app/oradata"]

EXPOSE 1521 22

ENTRYPOINT ["/assets/tini", "--"]

HEALTHCHECK --interval=1m --start-period=5m \
   CMD ["/assets/gosu", "oracle", "/assets/health_check.sh"]

CMD ["/assets/entrypoint.sh"]
