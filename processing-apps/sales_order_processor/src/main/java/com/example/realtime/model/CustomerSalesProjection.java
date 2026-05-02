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
public class CustomerSalesProjection implements Serializable {

    private String customerId;
    private String customerName;
    private String customerEmail;
    private String customerSegment;
    @Builder.Default
    private long orderCount = 0L;
    @Builder.Default
    private BigDecimal totalSpent = BigDecimal.ZERO;
    private String lastOrderId;
    private String updatedAt;
    private String currency;

    public static CustomerSalesProjection fromOrder(SalesOrderEvent event) {
        return CustomerSalesProjection.builder()
            .customerId(event.getCustomer().getCustomerId())
            .customerName(event.getCustomer().getFullName())
            .customerEmail(event.getCustomer().getEmail())
            .customerSegment(event.getCustomer().getSegment())
            .orderCount(1L)
            .totalSpent(event.getOrderTotal() == null ? BigDecimal.ZERO : event.getOrderTotal())
            .lastOrderId(event.getOrderId())
            .updatedAt(event.getOrderTimestamp())
            .currency(event.getCurrency())
            .build();
    }

    public CustomerSalesProjection accumulate(CustomerSalesProjection other) {
        boolean isOtherNewer = updatedAt == null || (other.updatedAt != null && other.updatedAt.compareTo(updatedAt) >= 0);
        orderCount = orderCount + other.orderCount;
        BigDecimal currentTotalSpent = totalSpent == null ? BigDecimal.ZERO : totalSpent;
        BigDecimal otherTotalSpent = other.totalSpent == null ? BigDecimal.ZERO : other.totalSpent;
        totalSpent = currentTotalSpent.add(otherTotalSpent);
        if (isOtherNewer) {
            lastOrderId = other.lastOrderId;
            updatedAt = other.updatedAt;
            customerName = other.customerName;
            customerEmail = other.customerEmail;
            customerSegment = other.customerSegment;
            currency = other.currency;
        }
        return this;
    }
}
