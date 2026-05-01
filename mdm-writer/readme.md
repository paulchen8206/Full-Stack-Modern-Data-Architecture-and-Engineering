# MDM Writer

This sub-project provides a service for writing Master Data Management (MDM) records to downstream systems as part of the GenAI-Enabled Data Platform.

## Overview
The MDM Writer consumes CDC (Change Data Capture) events or other master data records and persists them to target systems, such as data lakes, warehouses, or other analytical stores. It is designed to ensure that master data is reliably and efficiently available for analytics and operational use cases.

## Key Features
- Consumes MDM events (e.g., from Kafka)
- Writes master data to target storage (e.g., Iceberg, Postgres, S3, MinIO)
- Supports data transformation and enrichment
- Integrates with the platform's data pipelines
- Built for reliability and scalability

## Project Structure
- `app/`: Main application code
- `Dockerfile`: Container definition for deployment
- `pyproject.toml`: Python dependencies and project metadata

## Usage
1. Build the Docker image:
   ```sh
   docker build -t mdm-writer .
   ```
2. Run the service (example):
   ```sh
   docker run --rm mdm-writer
   ```
3. Configure environment variables and connections as needed for your deployment.

## Requirements
- Python 3.8+
- Access to target storage (e.g., S3, MinIO, Postgres, Iceberg)
- Kafka cluster for event consumption (if used)

## More Information
See the main project documentation for architecture and integration details.
