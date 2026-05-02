package com.example.realtime.model;

import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import java.io.Serializable;
import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SalesOrderLineItemProjection implements Serializable {

    private String orderId;
    private String orderTimestamp;
    private String customerId;
    private String customerName;
    private String lineItemId;
    private String sku;
    private String productName;
    @Builder.Default
    private int quantity = 0;
    @Builder.Default
    private BigDecimal unitPrice = BigDecimal.ZERO;
    @Builder.Default
    private BigDecimal lineTotal = BigDecimal.ZERO;
    private String currency;

    public static SalesOrderLineItemProjection fromEvent(SalesOrderEvent event, SalesOrderEvent.LineItem item) {
        return SalesOrderLineItemProjection.builder()
            .orderId(event.getOrderId())
            .orderTimestamp(event.getOrderTimestamp())
            .customerId(event.getCustomer().getCustomerId())
            .customerName(event.getCustomer().getFullName())
            .lineItemId(item.getLineItemId())
            .sku(item.getSku())
            .productName(item.getProductName())
            .quantity(item.getQuantity())
            .unitPrice(item.getUnitPrice() == null ? BigDecimal.ZERO : item.getUnitPrice())
            .lineTotal(item.getLineTotal() == null ? BigDecimal.ZERO : item.getLineTotal())
            .currency(event.getCurrency())
            .build();
    }
}
