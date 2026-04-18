FROM confluentinc/cp-kafka-connect:7.6.1

RUN confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:latest && \
  confluent-hub install --no-prompt confluentinc/kafka-connect-s3:latest && \
    curl -fsSL -o /usr/share/java/postgresql-42.7.4.jar \
      https://jdbc.postgresql.org/download/postgresql-42.7.4.jar
