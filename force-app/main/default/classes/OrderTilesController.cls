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
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public Date orderDate;
        @AuraEnabled public String orderStatus;
        @AuraEnabled public Date estimatedDeliveryDate;
        @AuraEnabled public List<OrderLineItem> lineItems;
        @AuraEnabled public String primaryProductImage;
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
        @AuraEnabled public String productImageUrl;
    }

    /**
     * @description Fetches orders for the current customer account
     * @param accountId The Account ID to fetch orders for
     * @param limitRecords Maximum number of orders to return
     * @return List of OrderData wrapper objects
     */
    @AuraEnabled(cacheable=true)
    public static List<OrderData> getCustomerOrders(String accountId, Integer limitRecords) {
        try {
            if (String.isBlank(accountId)) {
                // Get the current user's account
                accountId = getCurrentUserAccountId();
            }

            if (String.isBlank(accountId)) {
                return new List<OrderData>();
            }

            Integer queryLimit = (limitRecords != null && limitRecords > 0) ? limitRecords : 50;

            // Query orders with related line items
            List<Order> orders = [
                SELECT Id, OrderNumber, PoNumber, TotalAmount, CurrencyIsoCode,
                       EffectiveDate, Status, CreatedDate, AccountId,
                       (SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                               Product2.StockKeepingUnit, Quantity, UnitPrice,
                               TotalPrice, ServiceDate, Description,
                               OrderItemNumber
                        FROM OrderItems
                        ORDER BY OrderItemNumber)
                FROM Order
                WHERE AccountId = :accountId
                  AND Status != 'Draft'
                ORDER BY EffectiveDate DESC, CreatedDate DESC
                LIMIT :queryLimit
            ];

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

        // Collect all product IDs for image lookup
        Set<Id> productIds = new Set<Id>();
        for (Order ord : orders) {
            for (OrderItem oi : ord.OrderItems) {
                if (oi.Product2Id != null) {
                    productIds.add(oi.Product2Id);
                }
            }
        }

        // Get product images
        Map<Id, String> productImageMap = getProductImages(productIds);

        for (Order ord : orders) {
            OrderData orderData = new OrderData();
            orderData.orderId = ord.Id;
            orderData.orderNumber = ord.OrderNumber;
            orderData.customerPoNumber = ord.PoNumber;
            orderData.totalAmount = ord.TotalAmount;
            orderData.currencyCode = ord.CurrencyIsoCode;
            orderData.orderDate = ord.EffectiveDate;
            orderData.orderStatus = ord.Status;
            orderData.itemCount = ord.OrderItems.size();

            // Transform line items
            List<OrderLineItem> lineItems = new List<OrderLineItem>();
            Date earliestDelivery = null;
            String primaryImage = null;

            for (OrderItem oi : ord.OrderItems) {
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
                lineItem.lineStatus = 'Active'; // Customize based on your status field

                // Get product image
                if (productImageMap.containsKey(oi.Product2Id)) {
                    lineItem.productImageUrl = productImageMap.get(oi.Product2Id);
                    if (primaryImage == null) {
                        primaryImage = lineItem.productImageUrl;
                    }
                }

                // Track earliest delivery date
                if (oi.ServiceDate != null) {
                    if (earliestDelivery == null || oi.ServiceDate < earliestDelivery) {
                        earliestDelivery = oi.ServiceDate;
                    }
                }

                lineItems.add(lineItem);
            }

            orderData.lineItems = lineItems;
            orderData.estimatedDeliveryDate = earliestDelivery;
            orderData.primaryProductImage = primaryImage;

            orderDataList.add(orderData);
        }

        return orderDataList;
    }

    /**
     * @description Get product images from ProductMedia
     * @param productIds Set of Product IDs
     * @return Map of Product ID to image URL
     */
    private static Map<Id, String> getProductImages(Set<Id> productIds) {
        Map<Id, String> imageMap = new Map<Id, String>();

        if (productIds.isEmpty()) {
            return imageMap;
        }

        try {
            // Query ProductMedia for product images
            List<ProductMedia> productMedias = [
                SELECT ProductId, MediaUrl, Title
                FROM ProductMedia
                WHERE ProductId IN :productIds
                  AND MediaType = 'Image'
                ORDER BY SortOrder ASC NULLS LAST
            ];

            for (ProductMedia pm : productMedias) {
                if (!imageMap.containsKey(pm.ProductId)) {
                    imageMap.put(pm.ProductId, pm.MediaUrl);
                }
            }
        } catch (Exception e) {
            // ProductMedia might not be available in all orgs
            System.debug('Error fetching product images: ' + e.getMessage());
        }

        return imageMap;
    }

    /**
     * @description Initiate a reorder for a given order
     * @param orderId The Order ID to reorder
     * @return Cart ID or URL to redirect to
     */
    @AuraEnabled
    public static String initiateReorder(String orderId) {
        try {
            // This is a placeholder - implement based on your B2B Commerce setup
            // Typically you would:
            // 1. Get the order items
            // 2. Create a new cart or get active cart
            // 3. Add items to cart
            // 4. Return cart ID or checkout URL

            if (String.isBlank(orderId)) {
                throw new AuraHandledException('Order ID is required');
            }

            // Query the order and items
            Order originalOrder = [
                SELECT Id, AccountId,
                       (SELECT Product2Id, Quantity FROM OrderItems)
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];

            // TODO: Implement cart creation and item addition
            // This will depend on your specific B2B Commerce implementation
            // You may need to call ConnectApi.CommerceCart methods

            return orderId; // Return appropriate cart ID or URL

        } catch (Exception e) {
            throw new AuraHandledException('Error initiating reorder: ' + e.getMessage());
        }
    }
}
