FROM confluentinc/cp-kafka-connect:7.6.1

USER root
ENV PLUGIN_PATH="/usr/share/confluent-hub-components:/usr/share/java"
RUN yum install -y unzip curl && \
    yum clean all && \
    confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:latest && \
    confluent-hub install --no-prompt confluentinc/kafka-connect-s3:latest && \
    curl -fsSL -o /tmp/debezium-mysql-plugin.tar.gz https://repo1.maven.org/maven2/io/debezium/dbz-connector-mysql/2.5.2.Final/dbz-connector-mysql-2.5.2.Final-plugin.tar.gz && \
    mkdir -p /usr/share/confluent-hub-components/dbz-connector-mysql && \
    tar -xzf /tmp/debezium-mysql-plugin.tar.gz -C /usr/share/confluent-hub-components/dbz-connector-mysql --strip-components=1 && \
    rm -f /tmp/debezium-mysql-plugin.tar.gz && \
    curl -fsSL -o /usr/share/java/postgresql-42.7.4.jar https://jdbc.postgresql.org/download/postgresql-42.7.4.jar && \
    chmod -R a+rwX /usr/share/confluent-hub-components && \
    echo "plugin.path=/usr/share/confluent-hub-components,/usr/share/java" >> /etc/kafka/connect-distributed.properties && \
    echo "\n--- Plugin debug listing ---" && \
    ls -l /usr/share/confluent-hub-components && \
    ls -l /usr/share/confluent-hub-components/dbz-connector-mysql || true && \
    ls -l /usr/share/confluent-hub-components/dbz-connector-mysql/lib || true && \
    cat /etc/kafka/connect-distributed.properties || true
USER 1000
