# MDM CDC Producer

This sub-project is responsible for Change Data Capture (CDC) event production for Master Data Management (MDM) within the GenAI-Enabled Data Platform.

## Overview
The MDM CDC Producer monitors changes in master data sources (such as customer or product tables) and publishes CDC events to downstream systems, typically via Kafka. This enables real-time synchronization and propagation of master data changes across the platform.

## Key Features
- Captures inserts, updates, and deletes from MDM sources
- Publishes CDC events to Kafka topics
- Integrates with the platform's streaming and analytics pipelines
- Designed for reliability and scalability

## Project Structure
- `app/`: Main application code
- `Dockerfile`: Container definition for deployment
- `pyproject.toml`: Python dependencies and project metadata

## Usage
1. Build the Docker image:
   ```sh
   docker build -t mdm-cdc-producer .
   ```
2. Run the service (example):
   ```sh
   docker run --rm mdm-cdc-producer
   ```
3. Configure environment variables and connections as needed for your deployment.

## Requirements
- Python 3.8+
- Access to MDM data sources (e.g., MySQL, Postgres)
- Kafka cluster for event publishing

## More Information
See the main project documentation for architecture and integration details.
