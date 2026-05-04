# syntax=docker/dockerfile:1
FROM alpine:3.19

RUN apk add --no-cache bash curl jq

COPY platform-services/schemas/scripts/ /scripts/

RUN chmod +x /scripts/register-schemas.sh
COPY platform-services/schemas/avro /avro

WORKDIR /

ENV SCHEMA_REGISTRY_URL=http://schema-registry:8081
ENV SCHEMAS_DIR=/avro
ENV SCHEMA_REGISTRY_WAIT=true
ENV SCHEMA_REGISTRY_WAIT_INTERVAL_SEC=2

ENTRYPOINT ["/scripts/register-schemas.sh"]
