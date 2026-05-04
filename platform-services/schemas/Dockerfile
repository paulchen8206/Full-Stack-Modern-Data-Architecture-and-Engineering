# syntax=docker/dockerfile:1
FROM alpine:3.19

# Install bash, curl, and jq
RUN apk add --no-cache bash curl jq

# Copy canonical cicd schema registration scripts into the image
COPY cicd/scripts/register-schemas.sh /opt/cicd/scripts/register-schemas.sh
COPY cicd/scripts/lib/common.sh /opt/cicd/scripts/lib/common.sh
COPY cicd/scripts/lib/registration.sh /opt/cicd/scripts/lib/registration.sh
RUN chmod +x /opt/cicd/scripts/register-schemas.sh

# Copy schemas directory from repo-root build context.
COPY platform-services/schemas/avro /avro

WORKDIR /

ENV SCHEMA_REGISTRY_URL=http://schema-registry:8081
ENV SCHEMAS_DIR=/avro
ENV SCHEMA_REGISTRY_WAIT=true
ENV SCHEMA_REGISTRY_WAIT_INTERVAL_SEC=2

ENTRYPOINT ["/opt/cicd/scripts/register-schemas.sh"]
