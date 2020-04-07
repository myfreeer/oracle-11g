FROM centos:7

ADD assets /assets

ENV TINI_VERSION=v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-amd64 /assets/tini

ENV GOSU_VERSION=1.11
ADD https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64 /assets/gosu

RUN chmod -R 755 /assets && /assets/setup.sh

VOLUME ["/opt/oracle/app/oradata"]

EXPOSE 1521 22

ENTRYPOINT ["/assets/tini", "--"]


HEALTHCHECK --interval=1m --start-period=5m \
   CMD ["/assets/gosu", "oracle", "/assets/health_check.sh"]

CMD ["/assets/entrypoint.sh"]
