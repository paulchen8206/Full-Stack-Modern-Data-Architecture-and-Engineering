package com.example.realtime.serde;

import com.example.realtime.model.CustomerSalesProjection;
import com.example.realtime.model.SalesOrderLineItemProjection;
import com.example.realtime.model.SalesOrderProjection;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.flink.api.common.serialization.SerializationSchema;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class JsonSerializationSchema<T> implements SerializationSchema<T> {

    private transient ObjectMapper objectMapper;

    @Override
    public byte[] serialize(T element) {
        try {
            if (objectMapper == null) {
                objectMapper = new ObjectMapper();
            }
            return objectMapper.writeValueAsBytes(toConnectJsonEnvelope(element));
        } catch (JsonProcessingException exception) {
            throw new IllegalArgumentException("Unable to serialize record", exception);
        }
    }

    private Map<String, Object> toConnectJsonEnvelope(T element) {
        if (element instanceof SalesOrderProjection projection) {
            return envelope(
                    "com.example.realtime.SalesOrderProjection",
                    fields(
                            field("string", true, "orderId"),
                            timestampField("orderTimestamp"),
                            field("string", true, "customerId"),
                            field("string", true, "customerName"),
                            field("string", true, "customerEmail"),
                            field("string", true, "customerSegment"),
                            field("string", true, "currency"),
                            field("string", true, "orderTotal"),
                            field("int32", true, "lineItemCount")
                    ),
                    payload(
                            entry("orderId", projection.getOrderId()),
                            entry("orderTimestamp", toEpochMillis(projection.getOrderTimestamp())),
                            entry("customerId", projection.getCustomerId()),
                            entry("customerName", projection.getCustomerName()),
                            entry("customerEmail", projection.getCustomerEmail()),
                            entry("customerSegment", projection.getCustomerSegment()),
                            entry("currency", projection.getCurrency()),
                                entry("orderTotal", toDecimalString(projection.getOrderTotal())),
                            entry("lineItemCount", projection.getLineItemCount())
                    )
            );
        }

        if (element instanceof SalesOrderLineItemProjection projection) {
            return envelope(
                    "com.example.realtime.SalesOrderLineItemProjection",
                    fields(
                            field("string", true, "orderId"),
                            timestampField("orderTimestamp"),
                            field("string", true, "customerId"),
                            field("string", true, "customerName"),
                            field("string", true, "lineItemId"),
                            field("string", true, "sku"),
                            field("string", true, "productName"),
                            field("int32", true, "quantity"),
                                field("string", true, "unitPrice"),
                                field("string", true, "lineTotal"),
                            field("string", true, "currency")
                    ),
                    payload(
                            entry("orderId", projection.getOrderId()),
                            entry("orderTimestamp", toEpochMillis(projection.getOrderTimestamp())),
                            entry("customerId", projection.getCustomerId()),
                            entry("customerName", projection.getCustomerName()),
                            entry("lineItemId", projection.getLineItemId()),
                            entry("sku", projection.getSku()),
                            entry("productName", projection.getProductName()),
                            entry("quantity", projection.getQuantity()),
                                entry("unitPrice", toDecimalString(projection.getUnitPrice())),
                                entry("lineTotal", toDecimalString(projection.getLineTotal())),
                            entry("currency", projection.getCurrency())
                    )
            );
        }

        if (element instanceof CustomerSalesProjection projection) {
            return envelope(
                    "com.example.realtime.CustomerSalesProjection",
                    fields(
                            field("string", true, "customerId"),
                            field("string", true, "customerName"),
                            field("string", true, "customerEmail"),
                            field("string", true, "customerSegment"),
                            field("int64", true, "orderCount"),
                                field("string", true, "totalSpent"),
                            field("string", true, "lastOrderId"),
                                timestampField("updatedAt"),
                            field("string", true, "currency")
                    ),
                    payload(
                            entry("customerId", projection.getCustomerId()),
                            entry("customerName", projection.getCustomerName()),
                            entry("customerEmail", projection.getCustomerEmail()),
                            entry("customerSegment", projection.getCustomerSegment()),
                            entry("orderCount", projection.getOrderCount()),
                                entry("totalSpent", toDecimalString(projection.getTotalSpent())),
                            entry("lastOrderId", projection.getLastOrderId()),
                                entry("updatedAt", toEpochMillis(projection.getUpdatedAt())),
                            entry("currency", projection.getCurrency())
                    )
            );
        }

        throw new IllegalArgumentException("Unsupported projection type for schema envelope: " + element.getClass().getName());
    }

    private Map<String, Object> envelope(String schemaName, List<Map<String, Object>> fields, Map<String, Object> payload) {
        Map<String, Object> schema = new LinkedHashMap<>();
        schema.put("type", "struct");
        schema.put("optional", false);
        schema.put("name", schemaName);
        schema.put("fields", fields);

        Map<String, Object> envelope = new LinkedHashMap<>();
        envelope.put("schema", schema);
        envelope.put("payload", payload);
        return envelope;
    }

    @SafeVarargs
    private final List<Map<String, Object>> fields(Map<String, Object>... definitions) {
        List<Map<String, Object>> fieldList = new ArrayList<>();
        for (Map<String, Object> definition : definitions) {
            fieldList.add(definition);
        }
        return fieldList;
    }

    private Map<String, Object> field(String type, boolean optional, String fieldName) {
        Map<String, Object> field = new LinkedHashMap<>();
        field.put("type", type);
        field.put("optional", optional);
        field.put("field", fieldName);
        return field;
    }

    private Map<String, Object> timestampField(String fieldName) {
        Map<String, Object> field = new LinkedHashMap<>();
        field.put("type", "int64");
        field.put("optional", true);
        field.put("name", "org.apache.kafka.connect.data.Timestamp");
        field.put("version", 1);
        field.put("field", fieldName);
        return field;
    }

    @SafeVarargs
    private final Map<String, Object> payload(Map.Entry<String, Object>... entries) {
        Map<String, Object> payload = new LinkedHashMap<>();
        for (Map.Entry<String, Object> entry : entries) {
            payload.put(entry.getKey(), entry.getValue());
        }
        return payload;
    }

    private Map.Entry<String, Object> entry(String key, Object value) {
        return Map.entry(key, value);
    }

    private String toDecimalString(BigDecimal value) {
        return value == null ? null : value.toPlainString();
    }

    private Long toEpochMillis(String isoOffsetDateTime) {
        if (isoOffsetDateTime == null) {
            return null;
        }
        return OffsetDateTime.parse(isoOffsetDateTime).toInstant().toEpochMilli();
    }
}
