FROM confluentinc/cp-kafka-connect:7.6.1

USER root
ENV PLUGIN_PATH="/usr/share/confluent-hub-components:/usr/share/java"
RUN yum install -y unzip curl && \
    yum clean all && \
    confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:latest && \
    confluent-hub install --no-prompt confluentinc/kafka-connect-s3:latest && \
    confluent-hub install --no-prompt debezium/debezium-connector-mysql:latest && \
    curl -fsSL -o /usr/share/java/postgresql-42.7.4.jar https://jdbc.postgresql.org/download/postgresql-42.7.4.jar && \
    chmod -R a+rwX /usr/share/confluent-hub-components && \
    mv /usr/share/confluent-hub-components/debezium-debezium-connector-mysql/lib/*.jar /usr/share/confluent-hub-components/debezium-debezium-connector-mysql/ && \
    echo "plugin.path=/usr/share/confluent-hub-components,/usr/share/java" >> /etc/kafka/connect-distributed.properties && \
    echo "\n--- Plugin debug listing ---" && \
    ls -l /usr/share/confluent-hub-components && \
    ls -l /usr/share/confluent-hub-components/debezium-debezium-connector-mysql || true
USER 1000
