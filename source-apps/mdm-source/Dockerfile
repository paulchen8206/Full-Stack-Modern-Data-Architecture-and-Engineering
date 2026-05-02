FROM mysql:8.0

ENV MYSQL_ROOT_PASSWORD=mdmroot
ENV MYSQL_DATABASE=mdm
ENV MDM_SOURCE_INTERVAL_SEC=180

RUN microdnf install -y python3 python3-pip \
	&& pip3 install --no-cache-dir mysql-connector-python \
	&& microdnf clean all

COPY sql/init.sql /docker-entrypoint-initdb.d/init.sql
COPY entrypoint.sh /mdm-entrypoint.sh
COPY data-generator/main.py /opt/mdm-source/main.py

RUN chmod +x /mdm-entrypoint.sh

ENTRYPOINT ["/mdm-entrypoint.sh"]
CMD ["mysqld", "--server-id=223344", "--log-bin=mysql-bin", "--binlog-format=ROW", "--binlog-row-image=FULL"]
