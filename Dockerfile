FROM centos:7
MAINTAINER jaspeen

ADD assets /assets

RUN chmod -R 755 /assets && /assets/setup.sh

EXPOSE 1521 8080 22

CMD ["/assets/entrypoint.sh"]
