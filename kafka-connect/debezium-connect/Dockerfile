FROM confluentinc/cp-kafka-connect:7.6.1

USER root
ENV PLUGIN_PATH="/usr/share/confluent-hub-components:/usr/share/java"
RUN yum install -y unzip curl && \
    yum clean all && \
    curl -fsSL -o /tmp/debezium-mysql-plugin.tar.gz https://repo1.maven.org/maven2/io/debezium/debezium-connector-mysql/2.5.2.Final/debezium-connector-mysql-2.5.2.Final-plugin.tar.gz && \
    mkdir -p /usr/share/confluent-hub-components/debezium-connector-mysql && \
    tar -xzf /tmp/debezium-mysql-plugin.tar.gz -C /usr/share/confluent-hub-components/debezium-connector-mysql --strip-components=1 && \
    rm -f /tmp/debezium-mysql-plugin.tar.gz && \
    chmod -R a+rwX /usr/share/confluent-hub-components && \
    echo "plugin.path=/usr/share/confluent-hub-components,/usr/share/java" >> /etc/kafka/connect-distributed.properties && \
    echo "\n--- Plugin debug listing ---" && \
    ls -l /usr/share/confluent-hub-components && \
    ls -l /usr/share/confluent-hub-components/debezium-connector-mysql || true && \
    ls -l /usr/share/confluent-hub-components/debezium-connector-mysql/lib || true && \
    cat /etc/kafka/connect-distributed.properties || true
USER 1000
