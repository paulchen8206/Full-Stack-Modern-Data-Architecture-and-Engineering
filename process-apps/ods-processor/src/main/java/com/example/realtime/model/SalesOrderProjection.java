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
public class SalesOrderProjection implements Serializable {

    private String orderId;
    private String orderTimestamp;
    private String customerId;
    private String customerName;
    private String customerEmail;
    private String customerSegment;
    private String currency;
    @Builder.Default
    private BigDecimal orderTotal = BigDecimal.ZERO;
    @Builder.Default
    private int lineItemCount = 0;

    public static SalesOrderProjection fromEvent(SalesOrderEvent event) {
        return SalesOrderProjection.builder()
            .orderId(event.getOrderId())
            .orderTimestamp(event.getOrderTimestamp())
            .customerId(event.getCustomer().getCustomerId())
            .customerName(event.getCustomer().getFullName())
            .customerEmail(event.getCustomer().getEmail())
            .customerSegment(event.getCustomer().getSegment())
            .currency(event.getCurrency())
            .orderTotal(event.getOrderTotal() == null ? BigDecimal.ZERO : event.getOrderTotal())
            .lineItemCount(event.getLineItems().size())
            .build();
    }
}
