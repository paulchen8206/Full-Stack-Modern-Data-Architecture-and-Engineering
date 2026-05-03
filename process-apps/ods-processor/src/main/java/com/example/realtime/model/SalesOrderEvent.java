package com.example.realtime.model;

import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SalesOrderEvent implements Serializable {

    private String orderId;
    private String orderTimestamp;
    private String currency;
    @Builder.Default
    private BigDecimal orderTotal = BigDecimal.ZERO;
    private Customer customer;
    @Builder.Default
    private List<LineItem> lineItems = new ArrayList<>();

    public void setLineItems(List<LineItem> lineItems) {
        if (lineItems == null) {
            this.lineItems = new ArrayList<>();
            return;
        }
        this.lineItems = new ArrayList<>(lineItems);
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Customer implements Serializable {

        private String customerId;
        private String firstName;
        private String lastName;
        private String email;
        private String segment;

        public String getFullName() {
            return String.format("%s %s", firstName, lastName);
        }
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class LineItem implements Serializable {

        private String lineItemId;
        private String sku;
        private String productName;
        @Builder.Default
        private int quantity = 0;
        @Builder.Default
        private BigDecimal unitPrice = BigDecimal.ZERO;
        @Builder.Default
        private BigDecimal lineTotal = BigDecimal.ZERO;
    }
}
