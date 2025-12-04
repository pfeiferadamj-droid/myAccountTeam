# B2B Commerce Order Tiles Component

A custom Lightning Web Component (LWC) for Salesforce B2B Commerce storefronts that displays customer orders in an intuitive tile layout with comprehensive order details and reorder functionality.

## Features

- **Order Tiles Display**: Shows customer orders in a responsive grid layout with key information
- **Order Details**: Displays order number, date, status, PO number, estimated delivery, and total
- **Product Images**: Shows primary product image for each order with multi-item badge
- **Line Item Details**: View detailed line-level information including:
  - Product name, SKU, and image
  - Quantity and pricing (unit and total)
  - Line-level status
  - Estimated delivery date per line item
- **Interactive Actions**:
  - View Details: Opens a modal with complete order and line item information
  - Start Reorder: Initiates a reorder workflow (customizable based on your commerce implementation)
- **Responsive Design**: Optimized for desktop, tablet, and mobile devices
- **Configurable**: Admin-configurable properties for title, button visibility, and record limits

## Project Structure

```
force-app/main/default/
├── classes/
│   ├── OrderTilesController.cls          # Apex controller for order data
│   └── OrderTilesController.cls-meta.xml
└── lwc/
    └── orderTiles/
        ├── orderTiles.js                  # Component JavaScript logic
        ├── orderTiles.html                # Component HTML template
        ├── orderTiles.css                 # Component styles
        └── orderTiles.js-meta.xml         # Component metadata
```

## Installation

### Prerequisites

- Salesforce org with B2B Commerce enabled
- Salesforce CLI (sf or sfdx)
- Appropriate permissions to deploy metadata

### Deploy to Your Org

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd myAccountTeam
   ```

2. **Authenticate with your org**:
   ```bash
   sf org login web -a myOrg
   ```

3. **Deploy the component**:
   ```bash
   sf project deploy start --target-org myOrg
   ```

   Or using sfdx:
   ```bash
   sfdx force:source:deploy -p force-app -u myOrg
   ```

4. **Assign permissions** (if needed):
   - Ensure users have access to the `OrderTilesController` Apex class
   - Grant object permissions for Order, OrderItem, Product2, and ProductMedia objects

## Configuration

### Component Properties

The component exposes the following configurable properties in the Experience Builder or Lightning App Builder:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `accountId` | String | (current user's account) | Account ID to fetch orders for |
| `maxOrders` | Integer | 50 | Maximum number of orders to display |
| `cardTitle` | String | "My Orders" | Title displayed at the top of the component |
| `showReorderButton` | Boolean | true | Display the reorder button on each order tile |
| `showViewDetailsButton` | Boolean | true | Display the view details button on each order tile |

### Adding to Experience Cloud Sites

1. Navigate to **Experience Builder**
2. Select your B2B Commerce site
3. Go to the page where you want to add the component (e.g., My Account page)
4. Click **+ Component** in the page editor
5. Search for "Order Tiles" in the component list
6. Drag and drop the component to your desired location
7. Configure properties in the right panel
8. **Publish** the page

### Adding to Lightning Pages

1. Navigate to **Setup** → **Lightning App Builder**
2. Edit an existing page or create a new one
3. Find "Order Tiles" in the Custom components section
4. Drag it to your desired location on the page
5. Configure the component properties
6. **Save** and **Activate** the page

## Customization

### Modifying Order Data Fields

The `OrderTilesController.cls` queries standard Order and OrderItem fields. To add custom fields:

1. Update the SOQL query in `getCustomerOrders()` method:
   ```apex
   SELECT Id, OrderNumber, YourCustomField__c, ...
   ```

2. Add the field to the wrapper class:
   ```apex
   public class OrderData {
       @AuraEnabled public String customField;
       // ... other fields
   }
   ```

3. Map the field in `transformOrderData()` method

### Customizing the Reorder Function

The `initiateReorder()` method in `OrderTilesController.cls` is a placeholder. Implement it based on your commerce platform:

#### For Salesforce B2B Commerce (Lightning):

```apex
@AuraEnabled
public static String initiateReorder(String orderId) {
    // Get current user's cart
    ConnectApi.CartSummary cart = ConnectApi.CommerceCart.getOrCreateActiveCart(
        webstoreId,
        UserInfo.getUserId(),
        'active'
    );

    // Add order items to cart
    List<OrderItem> items = [SELECT Product2Id, Quantity FROM OrderItem WHERE OrderId = :orderId];

    for (OrderItem item : items) {
        ConnectApi.CartItemInput cartItem = new ConnectApi.CartItemInput();
        cartItem.productId = item.Product2Id;
        cartItem.quantity = String.valueOf(item.Quantity);
        cartItem.type = ConnectApi.CartItemType.PRODUCT;

        ConnectApi.CommerceCart.addItemToCart(webstoreId, 'active', cart.cartId, cartItem);
    }

    return cart.cartId;
}
```

### Styling Customization

Modify `orderTiles.css` to match your brand:

- **Colors**: Update color values for status badges, buttons, and text
- **Typography**: Change font sizes and weights
- **Spacing**: Adjust padding and margins
- **Grid Layout**: Modify grid columns in `.orders-grid`

Example color customization:
```css
.total-amount {
    color: #0176d3; /* Change to your brand color */
}

.status-processing {
    background-color: #your-color;
    color: #your-text-color;
}
```

## Data Model

### Order Object Fields Used

- `Id`, `OrderNumber`, `PoNumber`
- `TotalAmount`, `CurrencyIsoCode`
- `EffectiveDate`, `Status`
- `AccountId`

### OrderItem Fields Used

- `Id`, `Product2Id`, `Quantity`
- `UnitPrice`, `TotalPrice`
- `ServiceDate` (used for estimated delivery)
- `OrderItemNumber`

### Product2 Fields Used

- `Name`, `ProductCode`, `StockKeepingUnit`

### ProductMedia (Optional)

- `MediaUrl`, `MediaType`, `SortOrder`

## Troubleshooting

### No Orders Displayed

1. Verify the user's account has associated orders
2. Check order status (component excludes 'Draft' orders)
3. Verify user permissions on Order and OrderItem objects

### Images Not Loading

1. Check ProductMedia records exist for products
2. Verify MediaUrl field contains valid URLs
3. Ensure Content Security Policy allows image URLs
4. Update the default image path in `getDefaultImage()` method

### Reorder Not Working

1. Implement the `initiateReorder()` method based on your commerce setup
2. Verify user has permissions to create/modify carts
3. Check ConnectApi availability in your org

### Performance Issues

1. Reduce `maxOrders` property value
2. Add additional filters in SOQL query (e.g., date range)
3. Consider implementing pagination for large datasets
4. Enable caching in the `@AuraEnabled(cacheable=true)` method

## Best Practices

1. **Security**: The controller uses `with sharing` to enforce record-level security
2. **Caching**: The main data retrieval method is cacheable for better performance
3. **Error Handling**: Comprehensive error handling in both Apex and JavaScript
4. **Accessibility**: Uses semantic HTML and ARIA attributes
5. **Responsive Design**: Mobile-first CSS approach with media queries

## Future Enhancements

Potential additions to consider:

- Pagination for large order lists
- Order filtering (by status, date range, etc.)
- Order search functionality
- Export order data to PDF/CSV
- Order tracking integration
- Email notifications for order updates
- Guest checkout reorder support

## Support

For issues or questions:

1. Check Salesforce debug logs for Apex errors
2. Use browser developer console for JavaScript errors
3. Verify API version compatibility (currently 61.0)
4. Review Salesforce B2B Commerce documentation

## License

This component is provided as-is for use in Salesforce B2B Commerce implementations.

## Version History

- **v0.1.0** - Initial release
  - Order tiles display with key fields
  - Multi-line item support
  - View details modal
  - Reorder placeholder functionality
  - Responsive design
