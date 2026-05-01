FROM confluentinc/cp-kafka-connect:7.6.1

USER root
ENV PLUGIN_PATH="/usr/share/confluent-hub-components:/usr/share/java"
RUN yum install -y unzip curl && \
    yum clean all && \
    confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:latest && \
    confluent-hub install --no-prompt confluentinc/kafka-connect-s3:latest && \
    curl -fsSL -o /usr/share/java/postgresql-42.7.4.jar https://jdbc.postgresql.org/download/postgresql-42.7.4.jar && \
    chmod -R a+rwX /usr/share/confluent-hub-components && \
    echo "plugin.path=/usr/share/confluent-hub-components,/usr/share/java" >> /etc/kafka/connect-distributed.properties
