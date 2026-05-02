# Producer

This sub-project provides a data producer service for the GenAI-Enabled Data Platform.

## Overview
The Producer service is responsible for generating and publishing data events to Kafka topics or other streaming systems. It is typically used for simulating data, ingesting external data sources, or acting as a source in the platform's streaming pipelines.

## Key Features
- Publishes events to Kafka topics
- Supports batch and streaming data generation
- Configurable for different data schemas and topics
- Integrates with the platform's real-time and batch pipelines

## Project Structure
- `app/`: Main application code
- `Dockerfile`: Container definition for deployment
- `pyproject.toml`: Python dependencies and project metadata

## Usage
1. Build the Docker image:
   ```sh
   docker build -t producer .
   ```
2. Run the service (example):
   ```sh
   docker run --rm producer
   ```
3. Configure environment variables and data generation options as needed for your deployment.

## Requirements
- Python 3.8+
- Kafka cluster for event publishing

## More Information
See the main project documentation for architecture and integration details.
