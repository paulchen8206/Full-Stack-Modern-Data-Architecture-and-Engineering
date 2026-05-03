package com.example.realtime.job;

import com.example.realtime.config.RealtimeProperties;
import com.example.SalesOrder;
import com.example.LineItem;
import com.example.realtime.avro.SalesOrderProjection;
import com.example.realtime.avro.SalesOrderLineItemProjection;
import com.example.realtime.avro.CustomerSalesProjection;
import org.apache.flink.formats.avro.registry.confluent.ConfluentRegistryAvroDeserializationSchema;
import org.apache.flink.formats.avro.registry.confluent.ConfluentRegistryAvroSerializationSchema;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.formats.avro.AvroSerializationSchema;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.springframework.stereotype.Component;

@Component
public class RealtimeTopology {

    private final RealtimeProperties properties;

    public RealtimeTopology(RealtimeProperties properties) {
        this.properties = properties;
    }

    public void start() throws Exception {
        StreamExecutionEnvironment environment = StreamExecutionEnvironment.getExecutionEnvironment();
        environment.enableCheckpointing(properties.getCheckpointIntervalMs());

                OffsetsInitializer startingOffsets = "earliest".equalsIgnoreCase(properties.getConsumerStartOffset())
                                ? OffsetsInitializer.earliest()
                                : OffsetsInitializer.latest();

                KafkaSource<SalesOrder> rawSalesOrderSource = KafkaSource.<SalesOrder>builder()
                                .setBootstrapServers(properties.getKafkaBootstrapServers())
                                .setTopics(properties.getRawSalesOrdersTopic())
                                .setGroupId(properties.getConsumerGroupId())
                                .setStartingOffsets(startingOffsets)
                                .setValueOnlyDeserializer(
                                        ConfluentRegistryAvroDeserializationSchema.forSpecific(
                                                SalesOrder.class,
                                                properties.getSchemaRegistryUrl()
                                        )
                                )
                                .build();

        DataStream<SalesOrder> rawOrders = environment
                .fromSource(rawSalesOrderSource, WatermarkStrategy.noWatermarks(), "raw-sales-orders")
                .uid("raw-sales-orders-source");


                // Project raw orders into a single-record order stream used by downstream sinks.
                DataStream<SalesOrderProjection> salesOrders = rawOrders
                        .map(order -> SalesOrderProjection.newBuilder()
                                .setOrderId(order.getOrderId().toString())
                                .setOrderTimestamp(order.getOrderTimestamp().toString())
                                .setCustomerId(order.getCustomer().getCustomerId().toString())
                                .setCustomerName(order.getCustomer().getFirstName().toString() + " " + order.getCustomer().getLastName().toString())
                                .setCustomerEmail(order.getCustomer().getEmail().toString())
                                .setCustomerSegment(order.getCustomer().getSegment().toString())
                                .setCurrency(order.getCurrency().toString())
                                .setOrderTotal(java.nio.ByteBuffer.wrap(new java.math.BigDecimal(order.getOrderTotal().toString()).unscaledValue().toByteArray()))
                                .setLineItemCount(order.getLineItems().size())
                                .build())
                        .returns(TypeInformation.of(SalesOrderProjection.class))
                        .name("sales-order-projection");


                // Fan out each raw order into one record per line item for item-level analytics.
                DataStream<SalesOrderLineItemProjection> salesOrderLineItems = rawOrders
                                .flatMap((SalesOrder order, org.apache.flink.util.Collector<SalesOrderLineItemProjection> collector) -> {
                                        for (Object itemObj : order.getLineItems()) {
                                                LineItem item = (LineItem) itemObj;
                                                collector.collect(SalesOrderLineItemProjection.newBuilder()
                                                                .setOrderId(order.getOrderId().toString())
                                                                .setOrderTimestamp(order.getOrderTimestamp().toString())
                                                                .setCustomerId(order.getCustomer().getCustomerId().toString())
                                                                .setCustomerName(order.getCustomer().getFirstName().toString() + " " + order.getCustomer().getLastName().toString())
                                                                .setLineItemId(item.getLineItemId().toString())
                                                                .setSku(item.getSku().toString())
                                                                .setProductName(item.getProductName().toString())
                                                                .setQuantity(item.getQuantity())
                                                                .setUnitPrice(java.nio.ByteBuffer.wrap(new java.math.BigDecimal(item.getUnitPrice().toString()).unscaledValue().toByteArray()))
                                                                .setLineTotal(java.nio.ByteBuffer.wrap(new java.math.BigDecimal(item.getLineTotal().toString()).unscaledValue().toByteArray()))
                                                                .setCurrency(order.getCurrency().toString())
                                                                .build());
                                        }
                                })
                                .returns(TypeInformation.of(SalesOrderLineItemProjection.class))
                                .name("sales-order-line-item-projection");


                // Emit per-order customer facts; aggregation is intentionally deferred to downstream
                // warehouse/dbt layers instead of stateful Flink reduce logic.
                DataStream<CustomerSalesProjection> customerSales = rawOrders
                        .map(order -> CustomerSalesProjection.newBuilder()
                                .setCustomerId(order.getCustomer().getCustomerId().toString())
                                .setCustomerName(order.getCustomer().getFirstName().toString() + " " + order.getCustomer().getLastName().toString())
                                .setCustomerEmail(order.getCustomer().getEmail().toString())
                                .setCustomerSegment(order.getCustomer().getSegment().toString())
                                .setOrderCount(1L)
                                .setTotalSpent(java.nio.ByteBuffer.wrap(new java.math.BigDecimal(order.getOrderTotal().toString()).unscaledValue().toByteArray()))
                                .setLastOrderId(order.getOrderId().toString())
                                .setUpdatedAt(order.getOrderTimestamp().toString())
                                .setCurrency(order.getCurrency().toString())
                                .build())
                        .returns(TypeInformation.of(CustomerSalesProjection.class))
                        // .keyBy(CustomerSalesProjection::getCustomerId)
                        // .reduce(CustomerSalesProjection::accumulate)
                        .name("customer-sales-aggregation");

                salesOrders.sinkTo(buildAvroKafkaSink(properties.getSalesOrderTopic(), SalesOrderProjection.class)).name("sales-order-sink");
                salesOrderLineItems.sinkTo(buildAvroKafkaSink(properties.getSalesOrderLineItemTopic(), SalesOrderLineItemProjection.class)).name("sales-order-line-item-sink");
                customerSales.sinkTo(buildAvroKafkaSink(properties.getCustomerSalesTopic(), CustomerSalesProjection.class)).name("customer-sales-sink");

                environment.execute("pos-topology");
        }

        private <T extends org.apache.avro.specific.SpecificRecord> KafkaSink<T> buildAvroKafkaSink(String topic, Class<T> avroClass) {
        return KafkaSink.<T>builder()
                .setBootstrapServers(properties.getKafkaBootstrapServers())
                .setRecordSerializer(KafkaRecordSerializationSchema.<T>builder()
                        .setTopic(topic)
                        .setValueSerializationSchema(
                            ConfluentRegistryAvroSerializationSchema.forSpecific(
                                avroClass,
                                topic + "-value",
                                properties.getSchemaRegistryUrl() // Add this property to your config if not present
                            )
                        )
                        .build())
                .build();
    }
}
