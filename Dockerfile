FROM centos:7

ADD assets /assets

ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-amd64 /assets/tini

RUN chmod -R 755 /assets && /assets/setup.sh

VOLUME ["/opt/oracle/app/oradata"]

EXPOSE 1521 8080 22

ENTRYPOINT ["/assets/tini", "--"]

CMD ["/assets/entrypoint.sh"]
