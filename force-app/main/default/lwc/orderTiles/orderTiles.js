import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCustomerOrders from '@salesforce/apex/OrderTilesController.getCustomerOrders';
import initiateReorder from '@salesforce/apex/OrderTilesController.initiateReorder';

export default class OrderTiles extends NavigationMixin(LightningElement) {
    @api accountId;
    @api maxOrders = 50;
    @api cardTitle = 'My Orders';
    @api showReorderButton;
    @api showViewDetailsButton;

    @track orders = [];
    @track isLoading = true;
    @track error;
    @track selectedOrder;
    @track showOrderDetails = false;

    connectedCallback() {
        this.loadOrders();
    }

    loadOrders() {
        this.isLoading = true;
        this.error = null;

        getCustomerOrders({
            accountId: this.accountId,
            limitRecords: this.maxOrders
        })
            .then(result => {
                this.orders = result.map(order => ({
                    ...order,
                    formattedOrderDate: this.formatDate(order.orderDate),
                    formattedDeliveryDate: this.formatDate(order.estimatedDeliveryDate),
                    formattedTotal: this.formatCurrency(order.totalAmount),
                    statusClass: this.getStatusClass(order.orderStatus),
                    hasMultipleItems: order.itemCount > 1,
                    itemCountLabel: `${order.itemCount} item${order.itemCount !== 1 ? 's' : ''}`
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.error = this.handleError(error);
                this.isLoading = false;
            });
    }

    formatDate(dateValue) {
        if (!dateValue) return 'N/A';

        const date = new Date(dateValue);
        return new Intl.DateTimeFormat('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }).format(date);
    }

    formatCurrency(amount) {
        if (amount === null || amount === undefined) return 'N/A';

        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(amount);
    }

    getStatusClass(status) {
        const statusMap = {
            'Draft': 'status-draft',
            'Activated': 'status-activated',
            'Processing': 'status-processing',
            'Shipped': 'status-shipped',
            'Completed': 'status-completed',
            'Cancelled': 'status-cancelled'
        };
        return statusMap[status] || 'status-default';
    }

    handleViewDetails(event) {
        const orderId = event.currentTarget.dataset.orderId;
        const order = this.orders.find(o => o.orderId === orderId);

        if (order) {
            this.selectedOrder = {
                ...order,
                lineItems: order.lineItems.map(item => ({
                    ...item,
                    formattedUnitPrice: this.formatCurrency(item.unitPrice),
                    formattedTotalPrice: this.formatCurrency(item.totalPrice),
                    formattedDeliveryDate: this.formatDate(item.estimatedDeliveryDate)
                }))
            };
            this.showOrderDetails = true;
        }
    }

    handleCloseDetails() {
        this.showOrderDetails = false;
        this.selectedOrder = null;
    }

    handleReorder(event) {
        const orderId = event.currentTarget.dataset.orderId;

        initiateReorder({ orderId: orderId })
            .then(result => {
                this.showToast('Success', 'Items added to cart successfully', 'success');

                // Navigate to cart page
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: '/cart'
                    }
                });
            })
            .catch(error => {
                this.showToast('Error', this.handleError(error), 'error');
            });
    }

    handleNavigateToOrder(event) {
        const orderId = event.currentTarget.dataset.orderId;

        // Navigate to order record page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: orderId,
                objectApiName: 'Order',
                actionName: 'view'
            }
        });
    }

    handleError(error) {
        let message = 'Unknown error';
        if (error) {
            if (Array.isArray(error.body)) {
                message = error.body.map(e => e.message).join(', ');
            } else if (error.body && typeof error.body.message === 'string') {
                message = error.body.message;
            } else if (typeof error.message === 'string') {
                message = error.message;
            }
        }
        return message;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get hasOrders() {
        return this.orders && this.orders.length > 0;
    }

    get noOrdersMessage() {
        return 'No orders found for this account.';
    }

    get shouldShowReorderButton() {
        return this.showReorderButton !== false;
    }

    get shouldShowViewDetailsButton() {
        return this.showViewDetailsButton !== false;
    }
}
