# syntax=docker/dockerfile:1
FROM alpine:3.19

# Install bash, curl, and jq
RUN apk add --no-cache bash curl jq

# Copy the schema registration script into the image
COPY register-schemas.sh register-schemas.sh
RUN chmod +x register-schemas.sh

# Copy schemas directory (optional, if needed by the script)
COPY avro /avro

WORKDIR /

ENTRYPOINT ["./register-schemas.sh"]
