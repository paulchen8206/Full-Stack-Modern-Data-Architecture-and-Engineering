FROM maven:3.9.9-eclipse-temurin-17 AS build

WORKDIR /workspace

COPY pom.xml ./
COPY src ./src

RUN mvn -q -DskipTests package


FROM eclipse-temurin:17-jre

# Install netcat for wait-for-it.sh
RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /workspace/target/realtime-processor-0.1.0-all.jar /app/app.jar

# Copy application.yaml for Spring Boot config
COPY src/main/resources/application.yaml /app/application.yaml

# Copy wait-for-it.sh script
COPY wait-for-it.sh /usr/local/bin/wait-for-it.sh
RUN chmod +x /usr/local/bin/wait-for-it.sh

ENTRYPOINT ["/usr/local/bin/wait-for-it.sh", "schema-registry:8081", "--timeout=60", "java", "--add-opens=java.base/java.util=ALL-UNNAMED", "-jar", "/app/app.jar"]
