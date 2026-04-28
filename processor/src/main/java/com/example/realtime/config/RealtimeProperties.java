
package com.example.realtime.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "app")
public class RealtimeProperties {

    private String kafkaBootstrapServers = "localhost:9094";
    private String rawSalesOrdersTopic = "raw_sales_orders";
    private String salesOrderTopic = "bronze.sales_order";
    private String salesOrderLineItemTopic = "bronze.sales_order_line_item";
    private String customerSalesTopic = "bronze.customer_sales";
    private String consumerGroupId = "realtime-flink-processor";
    private long checkpointIntervalMs = 10000L;
    private String schemaRegistryUrl = "http://schema-registry:8081";

    public String getKafkaBootstrapServers() {
        return kafkaBootstrapServers;
    }

    public void setKafkaBootstrapServers(String kafkaBootstrapServers) {
        this.kafkaBootstrapServers = kafkaBootstrapServers;
    }

    public String getRawSalesOrdersTopic() {
        return rawSalesOrdersTopic;
    }

    public void setRawSalesOrdersTopic(String rawSalesOrdersTopic) {
        this.rawSalesOrdersTopic = rawSalesOrdersTopic;
    }

    public String getSalesOrderTopic() {
        return salesOrderTopic;
    }

    public void setSalesOrderTopic(String salesOrderTopic) {
        this.salesOrderTopic = salesOrderTopic;
    }

    public String getSalesOrderLineItemTopic() {
        return salesOrderLineItemTopic;
    }

    public void setSalesOrderLineItemTopic(String salesOrderLineItemTopic) {
        this.salesOrderLineItemTopic = salesOrderLineItemTopic;
    }

    public String getCustomerSalesTopic() {
        return customerSalesTopic;
    }

    public void setCustomerSalesTopic(String customerSalesTopic) {
        this.customerSalesTopic = customerSalesTopic;
    }

    public String getConsumerGroupId() {
        return consumerGroupId;
    }

    public void setConsumerGroupId(String consumerGroupId) {
        this.consumerGroupId = consumerGroupId;
    }

    public long getCheckpointIntervalMs() {
        return checkpointIntervalMs;
    }

    public void setCheckpointIntervalMs(long checkpointIntervalMs) {
        this.checkpointIntervalMs = checkpointIntervalMs;
    }

    public String getSchemaRegistryUrl() {
        return schemaRegistryUrl;
    }

    public void setSchemaRegistryUrl(String schemaRegistryUrl) {
        this.schemaRegistryUrl = schemaRegistryUrl;
    }
}
