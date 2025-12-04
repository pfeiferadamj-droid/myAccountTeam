/**
 * @description Controller for Order Tiles LWC component
 * Fetches customer order data for B2B Commerce storefront
 */
public with sharing class OrderTilesController {

    /**
     * @description Wrapper class for Order data with line items
     */
    public class OrderData {
        @AuraEnabled public String orderId;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String customerPoNumber;
        @AuraEnabled public String customerPoNumberSAP;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Date orderDate;
        @AuraEnabled public String orderStatus;
        @AuraEnabled public String productionStatusSAP;
        @AuraEnabled public Date estimatedDeliveryDate;
        @AuraEnabled public Date revisedDeliveryDateSAP;
        @AuraEnabled public List<OrderLineItem> lineItems;
        @AuraEnabled public Integer itemCount;
    }

    /**
     * @description Wrapper class for Order Line Item data
     */
    public class OrderLineItem {
        @AuraEnabled public String lineItemId;
        @AuraEnabled public String productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productSku;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public String lineStatus;
        @AuraEnabled public Date estimatedDeliveryDate;
    }

    /**
     * @description Fetches orders for the current customer account
     * @param accountId The Account ID to fetch orders for
     * @param limitRecords Maximum number of orders to return
     * @param searchTerm Search term for Customer PO Number
     * @param startDate Start date for order date filter
     * @param endDate End date for order date filter
     * @return List of OrderData wrapper objects
     */
    @AuraEnabled(cacheable=true)
    public static List<OrderData> getCustomerOrders(
        String accountId,
        Integer limitRecords,
        String searchTerm,
        Date startDate,
        Date endDate
    ) {
        try {
            if (String.isBlank(accountId)) {
                // Get the current user's account
                accountId = getCurrentUserAccountId();
            }

            if (String.isBlank(accountId)) {
                return new List<OrderData>();
            }

            Integer queryLimit = (limitRecords != null && limitRecords > 0) ? limitRecords : 50;

            // Build dynamic query
            String query = 'SELECT Id, OrderNumber, PoNumber, TotalAmount, ' +
                          'EffectiveDate, Status, CreatedDate, AccountId, ' +
                          'Customer_PO_Number_SAP__c, Production_Status_SAP__c, ' +
                          'Revised_Delivery_Date_SAP__c, ' +
                          '(SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, ' +
                          'Product2.StockKeepingUnit, Product2.Family, ' +
                          'Quantity, UnitPrice, TotalPrice, ServiceDate, ' +
                          'Description, OrderItemNumber, Production_Status_SAP__c ' +
                          'FROM OrderItems ORDER BY OrderItemNumber) ' +
                          'FROM Order ' +
                          'WHERE AccountId = :accountId AND Status != \'Draft\'';

            // Add search filter
            if (String.isNotBlank(searchTerm)) {
                String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
                query += ' AND (Customer_PO_Number_SAP__c LIKE :searchPattern ' +
                        'OR PoNumber LIKE :searchPattern ' +
                        'OR OrderNumber LIKE :searchPattern)';
            }

            // Add date range filters
            if (startDate != null) {
                query += ' AND EffectiveDate >= :startDate';
            }
            if (endDate != null) {
                query += ' AND EffectiveDate <= :endDate';
            }

            query += ' ORDER BY EffectiveDate DESC, CreatedDate DESC LIMIT :queryLimit';

            // Execute dynamic query
            List<Order> orders = Database.query(query);

            return transformOrderData(orders);

        } catch (Exception e) {
            throw new AuraHandledException('Error fetching orders: ' + e.getMessage());
        }
    }

    /**
     * @description Get current user's account ID
     * @return Account ID of current user
     */
    private static String getCurrentUserAccountId() {
        try {
            User currentUser = [
                SELECT AccountId, ContactId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            return currentUser.AccountId;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Transform Order records to OrderData wrapper
     * @param orders List of Order records
     * @return List of OrderData wrapper objects
     */
    private static List<OrderData> transformOrderData(List<Order> orders) {
        List<OrderData> orderDataList = new List<OrderData>();

        for (Order ord : orders) {
            OrderData orderData = new OrderData();
            orderData.orderId = ord.Id;
            orderData.orderNumber = ord.OrderNumber;
            orderData.customerPoNumber = ord.PoNumber;
            orderData.customerPoNumberSAP = ord.Customer_PO_Number_SAP__c;
            orderData.totalAmount = ord.TotalAmount;
            orderData.orderDate = ord.EffectiveDate;
            orderData.orderStatus = ord.Status;
            orderData.productionStatusSAP = ord.Production_Status_SAP__c;
            orderData.revisedDeliveryDateSAP = ord.Revised_Delivery_Date_SAP__c;

            // Transform line items (excluding shipping products)
            List<OrderLineItem> lineItems = new List<OrderLineItem>();
            Date earliestDelivery = null;
            Date earliestRevisedDelivery = null;

            for (OrderItem oi : ord.OrderItems) {
                // Skip shipping products
                if (isShippingProduct(oi)) {
                    continue;
                }

                OrderLineItem lineItem = new OrderLineItem();
                lineItem.lineItemId = oi.Id;
                lineItem.productId = oi.Product2Id;
                lineItem.productName = oi.Product2.Name;
                lineItem.productSku = oi.Product2.StockKeepingUnit != null ?
                                     oi.Product2.StockKeepingUnit :
                                     oi.Product2.ProductCode;
                lineItem.quantity = oi.Quantity;
                lineItem.unitPrice = oi.UnitPrice;
                lineItem.totalPrice = oi.TotalPrice;
                lineItem.estimatedDeliveryDate = oi.ServiceDate;
                lineItem.lineStatus = (String) oi.get('Production_Status_SAP__c');

                // Track earliest delivery date (standard)
                if (oi.ServiceDate != null) {
                    if (earliestDelivery == null || oi.ServiceDate < earliestDelivery) {
                        earliestDelivery = oi.ServiceDate;
                    }
                }

                lineItems.add(lineItem);
            }

            orderData.lineItems = lineItems;
            orderData.itemCount = lineItems.size();
            orderData.estimatedDeliveryDate = earliestDelivery;

            orderDataList.add(orderData);
        }

        return orderDataList;
    }

    /**
     * @description Check if an order item is a shipping product
     * @param orderItem The OrderItem to check
     * @return True if this is a shipping product
     */
    private static Boolean isShippingProduct(OrderItem orderItem) {
        if (orderItem.Product2Id == null) {
            return false;
        }

        // Check Product Family
        if (orderItem.Product2.Family != null &&
            orderItem.Product2.Family.containsIgnoreCase('Shipping')) {
            return true;
        }

        // Check Product Code
        if (orderItem.Product2.ProductCode != null &&
            (orderItem.Product2.ProductCode.containsIgnoreCase('SHIP') ||
             orderItem.Product2.ProductCode.containsIgnoreCase('FREIGHT'))) {
            return true;
        }

        // Check Product Name
        if (orderItem.Product2.Name != null &&
            (orderItem.Product2.Name.containsIgnoreCase('Shipping') ||
             orderItem.Product2.Name.containsIgnoreCase('Freight'))) {
            return true;
        }

        return false;
    }

    /**
     * @description Initiate a reorder for a given order
     * @param orderId The Order ID to reorder
     * @param webstoreId The webstore ID for B2B Commerce
     * @return Cart ID
     */
    @AuraEnabled
    public static String initiateReorder(String orderId, String webstoreId) {
        try {
            if (String.isBlank(orderId)) {
                throw new AuraHandledException('Order ID is required');
            }

            // Query the order and items (excluding shipping products)
            Order originalOrder = [
                SELECT Id, AccountId,
                       (SELECT Product2Id, Product2.Family, Product2.ProductCode,
                               Product2.Name, Quantity
                        FROM OrderItems)
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];

            // Get or create active cart
            String effectiveAccountId = originalOrder.AccountId;
            ConnectApi.CartSummary cartSummary;

            try {
                cartSummary = ConnectApi.CommerceCart.getOrCreateActiveCartSummary(
                    webstoreId,
                    effectiveAccountId,
                    'active'
                );
            } catch (Exception e) {
                throw new AuraHandledException('Unable to access cart: ' + e.getMessage());
            }

            // Add each non-shipping item to cart
            Integer itemsAdded = 0;
            for (OrderItem oi : originalOrder.OrderItems) {
                // Skip shipping products
                if (isShippingProduct(oi)) {
                    continue;
                }

                try {
                    ConnectApi.CartItemInput cartInput = new ConnectApi.CartItemInput();
                    cartInput.productId = oi.Product2Id;
                    cartInput.quantity = String.valueOf(oi.Quantity);
                    cartInput.type = ConnectApi.CartItemType.PRODUCT;

                    ConnectApi.CommerceCart.addItemToCart(
                        webstoreId,
                        effectiveAccountId,
                        'active',
                        cartInput
                    );

                    itemsAdded++;
                } catch (Exception e) {
                    System.debug('Error adding product ' + oi.Product2Id + ' to cart: ' + e.getMessage());
                    // Continue with next item
                }
            }

            if (itemsAdded == 0) {
                throw new AuraHandledException('No items could be added to cart');
            }

            return cartSummary.cartId;

        } catch (Exception e) {
            throw new AuraHandledException('Error initiating reorder: ' + e.getMessage());
        }
    }
}
