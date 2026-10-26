# Trend Kicks — Feature Specification

## 1. Purpose

This document defines the functional behavior of the Trend Kicks Flutter e-commerce application.

Trend Kicks is a self-owned shoe e-commerce store.

There are two primary user roles:

- Customer
- Administrator

There is no seller marketplace and there is no seller-registration system.

Administrators act as the store managers and are responsible for managing products, inventory, orders, refunds, and other administrative functions.

This document defines what the application must be able to do.

The UI and visual implementation should follow `02_UI_UX.md`.

The technical implementation must follow the project's Flutter, Firebase, and architecture documentation.

---

## 2. User Roles

### Customer

Customers can:

- Register
- Log in
- Browse shoes
- Search shoes
- Filter shoes
- Sort shoes
- View product details
- Select size
- Select color
- Add products to cart
- Change cart quantities
- Buy products immediately
- Checkout
- Choose delivery information
- Choose payment method
- Place orders
- View order history
- Track orders
- Cancel eligible orders
- Request refunds
- View refund status
- Review delivered products
- Edit their profile
- View notifications
- Log out

### Administrator

Administrators can:

- Log in
- View the admin dashboard
- Add products
- Edit products
- Delete products
- Upload product images
- Manage product sizes
- Manage product colors
- Manage inventory
- View orders
- Update order statuses
- View products sold
- View refund requests
- Approve refunds
- Reject refunds
- View customer/order information necessary for store operations

Administrators have access to store-management functionality that normal customers do not have.

---

## 3. No Seller Marketplace

Trend Kicks is a self-owned shoe store.

There is no marketplace where individual sellers register and sell their own products.

Therefore, do not create:

- Seller registration
- Seller request
- Seller profiles
- Seller dashboards
- Seller product ownership
- Seller approval
- Seller-specific product management

Products are managed by Trend Kicks administrators.

The administrator represents the store.

---

## 4. Registration

Customers must create an account before using account-based functionality.

Registration requires:

- First name
- Last name
- Email
- Password
- Confirm password
- Phone number
- Delivery address

A profile picture may also be supported.

After successful registration, the customer should automatically become logged in.

The intended flow is:

    Register
        ↓
    Firebase Authentication account created
        ↓
    Customer profile created
        ↓
    Customer automatically logged in
        ↓
    Home

The customer should not be required to manually log in again immediately after successfully registering.

---

## 5. Authentication

Firebase Authentication should be used for customer authentication.

The application must support:

- Registration
- Login
- Logout
- Persistent login sessions

The application should determine whether the user is already authenticated when it starts.

If the user is authenticated:

    App Start
        ↓
    Authenticated?
        ↓
    Yes
        ↓
    Home

If the user is not authenticated:

    App Start
        ↓
    Authenticated?
        ↓
    No
        ↓
    Login

---

## 6. Login Persistence

Customers should remain logged in after closing and reopening the application.

Example:

    User logs in
        ↓
    Home
        ↓
    Application closed
        ↓
    Application reopened
        ↓
    User remains logged in

The customer should only become logged out when they explicitly choose the Logout action or when authentication is otherwise invalidated.

---

## 7. Logout

When a customer chooses Logout:

    Profile
        ↓
    Logout
        ↓
    Firebase session signed out
        ↓
    Login

After logout, the application must not continue displaying the previous customer's private account information.

The next user who logs in must see their own:

- Profile
- Cart
- Orders
- Notifications
- Refund requests
- Reviews

---

## 8. Admin Authentication

The administrator account must NOT be created through normal customer registration.

The initial administrator account should be created manually by the developer or authorized project administrator.

The administrator's role should be stored securely.

Normal customers must never be able to:

- Select "Admin" during registration
- Modify their own role
- Access admin screens by changing client-side values
- Access administrative Firebase data

Administrative authorization must be enforced using Firebase Security Rules and appropriate authentication/authorization logic.

---

## 9. Product Catalog

The store initially supports three brands:

- Nike
- Puma
- Adidas

Products must contain the information required by the application.

A product should support:

- Product ID
- Product name
- Brand
- Description
- Price
- Images
- Available sizes
- Available colors
- Stock
- Ratings
- Number of reviews
- Product availability

The exact Firebase data structure should be determined by the Firebase architecture documentation.

---

## 10. Product Variants

Each product can have multiple:

- Sizes
- Colors

The administrator should be able to define which sizes and colors are available for each product.

Example:

    Jordan 3
    Brand: Nike

    Colors:
    - Red
    - Black
    - White

    Sizes:
    - 7
    - 8
    - 9
    - 10
    - 11

Only sizes and colors configured for that product should appear to customers.

---

## 11. Size and Color Inventory

Inventory should be tracked based on the product's size/color combination.

Example:

    Jordan 3
    Color: Red

    Size 7  → 3 available
    Size 8  → 5 available
    Size 9  → 2 available
    Size 10 → 0 available

This allows the application to accurately determine whether a specific variant is available.

The application must not treat all variants as having one shared stock count if variant-level stock is being used.

---

## 12. Stock Validation

The application must prevent customers from purchasing more items than are available.

Example:

    Jordan 3
    Red
    Size 9
    Stock = 5

The customer should be able to select:

- 1
- 2
- 3
- 4
- 5

But not:

- 6

If the customer attempts to exceed the available quantity, the application should:

- Prevent the quantity from increasing beyond available stock
- Inform the customer that there is insufficient stock
- Clearly communicate when the product/variant is out of stock

Example messages:

    Only 5 items are available.

or:

    No stock left.

---

## 13. Product Search

Customers can search products by name.

Search should support partial matches.

Example:

    Search:
    Jordan

can return:

- Jordan 2
- Jordan 3
- Jordan 4
- Jordan 11

and other products whose names match the search.

The customer does not need to know the exact product name.

Search should return relevant matching products.

---

## 14. Product Filtering

Customers can filter products by brand.

Initial filters:

- All
- Nike
- Puma
- Adidas

Filtering should update the visible product list.

---

## 15. Product Sorting

Customers can sort products by rating.

Supported options:

- Highest rated
- Lowest rated

Sorting should operate on the available products shown in the current product listing.

---

## 16. Product Details

Customers should be able to open a product and view:

- Product name
- Brand
- Images
- Price
- Description
- Rating
- Number of reviews
- Available sizes
- Available colors
- Stock availability

Customers must select the required product variant before purchasing.

---

## 17. Product Selection

Before adding a product to the cart or buying it immediately, the customer must select the required:

- Size
- Color
- Quantity

The application must validate that the selected variant exists and has sufficient stock.

---

## 18. Add to Cart

Customers can add products to their cart.

A cart item should contain enough information to identify the exact variant.

Example:

    Product:
    Jordan 3

    Size:
    9

    Color:
    Red

    Quantity:
    2

Adding the same product variant again may increase its quantity rather than creating unnecessary duplicate cart entries.

Different variants should remain separate cart items.

Example:

    Jordan 3
    Red
    Size 9
    Quantity 2

    Jordan 3
    Black
    Size 10
    Quantity 1

---

## 19. Cart Persistence

The customer's cart must be associated with their Firebase account.

The cart must not disappear simply because the application is closed.

Example:

    User A logs in
        ↓
    Adds Jordan 3
        ↓
    Closes application
        ↓
    Reopens application
        ↓
    Jordan 3 remains in User A's cart

Each customer must have their own cart.

User A must never see User B's cart.

---

## 20. Cart Quantity

Customers can increase or decrease item quantities.

Example:

    [-]  2  [+]

The quantity must never exceed the available stock for the selected product variant.

If only 5 units are available:

    1 → 2 → 3 → 4 → 5

The customer cannot increase it to:

    6

The customer should receive appropriate feedback if stock changes and their existing cart quantity is no longer valid.

---

## 21. Remove From Cart

Customers can remove individual items from their cart.

Removing an item should update the customer's stored cart.

The cart total should update accordingly.

---

## 22. Buy Now

Buy Now should immediately proceed to checkout using the selected product.

The flow is:

    Shoe Detail
        ↓
    Select Size
        ↓
    Select Color
        ↓
    Select Quantity
        ↓
    Buy Now
        ↓
    Checkout

Buy Now should not require the customer to manually navigate through the Cart first.

The selected product must still be validated against current inventory.

---

## 23. Checkout

Checkout should display:

- Selected products
- Product variants
- Quantity
- Item subtotal
- Shipping fee
- Final total
- Delivery address
- Payment method

The final total must include the shipping fee.

Example:

    Items:
    ₱2,500

    Shipping:
    ₱100

    Total:
    ₱2,600

The actual shipping fee can be defined separately in the application configuration.

---

## 24. Delivery Only

Trend Kicks uses delivery only.

There is no store pickup option.

The checkout flow is:

    Cart / Buy Now
        ↓
    Checkout
        ↓
    Delivery Address
        ↓
    Shipping Fee
        ↓
    Payment Method
        ↓
    Place Order

Do not implement store pickup.

---

## 25. Delivery Address

The customer's delivery address is stored as part of their account.

The checkout should use the customer's saved address.

The customer should be able to edit their address through their profile.

The order should store the delivery address used at the time the order was placed.

This is important because a customer's profile address may change later.

An old order should retain the delivery information that was used for that order.

---

## 26. Payment Methods

The intended payment methods are:

- GCash
- Maya
- Cash on Delivery

The exact online payment integration is currently pending instructor clarification.

The application architecture should allow the payment implementation to be updated later without redesigning the entire ordering system.

Do not implement an invented payment gateway or fake payment verification system.

---

## 27. Order Creation

When the customer successfully places an order, an order record should be created.

The order should contain information such as:

- Order ID
- Customer ID
- Product information
- Product ID
- Product name
- Size
- Color
- Quantity
- Item price
- Total price
- Shipping fee
- Final total
- Shipping address
- Order date
- Payment method
- Order status

The exact database structure should be defined in the Firebase architecture documentation.

---

## 28. Order Status

The initial order status flow is:

    Pending
        ↓
    Confirmed
        ↓
    Preparing
        ↓
    Shipped
        ↓
    Delivered

An order may also become:

    Cancelled

when cancellation requirements are satisfied.

---

## 29. Admin Order Status Management

Administrators can update order statuses.

For example:

    Pending
        ↓
    Confirmed
        ↓
    Preparing
        ↓
    Shipped
        ↓
    Delivered

When the administrator changes the status, the customer's order tracking should update accordingly.

The customer should not be able to manually change their own order status.

---

## 30. Order Tracking

Customers should be able to view the current status of their order.

The tracking interface should communicate the order's progress.

Example:

    ✓ Pending
    ✓ Confirmed
    ✓ Preparing
    ● Shipped
    ○ Delivered

The exact visual representation is defined in `02_UI_UX.md`.

---

## 31. Order History

Customers can view their previous orders.

Each order should display relevant information such as:

- Order ID
- Date
- Products
- Total
- Status

Customers can open an order to see its details and tracking information.

---

## 32. Customer Order Privacy

Customers can only access their own orders.

User A must not be able to retrieve User B's:

- Orders
- Addresses
- Cart
- Notifications
- Refund requests
- Private account information

Firebase Security Rules must enforce this restriction.

---

## 33. Admin Order Access

Administrators can access the orders necessary to operate the store.

Administrators can view:

- Customer order information
- Ordered products
- Quantity
- Size
- Color
- Total
- Shipping address
- Payment method
- Order date
- Order status

Administrative access must be protected by authorization rules.

---

## 34. Order Cancellation

Customers can cancel an order only while it has not yet been shipped.

Once an order becomes:

    Shipped

the customer can no longer cancel it.

Example:

    Pending       → Can cancel
    Confirmed     → Can cancel
    Preparing     → Can cancel
    Shipped       → Cannot cancel
    Delivered     → Cannot cancel

The application should confirm the customer's intention before cancelling the order.

---

## 35. Cancellation Status

When a valid cancellation is completed:

    Order status = Cancelled

The customer should see the updated status in:

- Order history
- Order details
- Tracking

The appropriate notification should also be generated.

---

## 36. Refund System

Customers can request a refund for an individual item.

Refunds are item-specific.

Example:

    Order #1001

    Jordan 3 → Refund requested
    Puma RS  → No refund
    Adidas   → No refund

The entire order does not automatically become a refund request.

---

## 37. Refund Request Flow

The refund process is:

    Customer opens order
        ↓
    Selects specific item
        ↓
    Request Refund
        ↓
    Select predefined reason
        ↓
    Submit request
        ↓
    Admin reviews request
        ↓
    Approve / Reject

The customer should be able to see the current refund request status.

---

## 38. Refund Reasons

The refund request should provide predefined reasons.

Possible examples include:

- Product arrived damaged
- Wrong product received
- Wrong size received
- Product does not match the order
- Defective product
- Other eligible reason

The final list can be adjusted according to project requirements.

---

## 39. Refund Review

Only authorized administrators can review refund requests.

Administrators can:

- View refund request
- View related order
- View affected product
- View selected reason
- Approve request
- Reject request

Customers cannot approve their own refund requests.

---

## 40. Refund Status

Refund requests should support statuses such as:

- Pending Review
- Approved
- Rejected

The customer should be able to see the current status.

The administrator's decision should update the corresponding refund request.

---

## 41. Product Reviews

Customers can review products they have purchased.

A customer can review an item after the order containing that item has been delivered.

Example:

    Order:
    Jordan 3

    Status:
    Delivered

    → Review available

If the item has not been delivered:

    Status:
    Preparing

    → Review unavailable

---

## 42. Product Rating

Customers can submit a star rating:

- 1 star
- 2 stars
- 3 stars
- 4 stars
- 5 stars

The product should display:

- Average rating
- Number of reviews

The rating should be calculated from submitted reviews rather than manually entered by the customer.

---

## 43. Written Reviews

Customers may provide a written review along with their star rating.

The review should be associated with:

- Customer
- Product
- Order/item
- Rating
- Review text
- Date

Customers should not be able to review products they have not purchased according to the review eligibility rule.

---

## 44. Review Restrictions

A customer should not be able to repeatedly create unlimited reviews for the same purchased item unless the documented requirements explicitly allow it.

The application should prevent obvious duplicate-review abuse.

---

## 45. Notifications

The application must support in-app notifications.

Notifications can be generated for important events.

Examples:

- Order confirmed
- Order preparing
- Order shipped
- Order delivered
- Order cancelled
- Refund approved
- Refund rejected

---

## 46. Automatic Order Notifications

When an administrator changes an order status, the system should generate an appropriate customer notification.

Example:

    Admin:
    Preparing → Shipped

    System:
    Create notification

    Customer:
    "Your order has been shipped."

The notification should be associated with the correct customer.

---

## 47. Notification Privacy

Customers can only view their own notifications.

User A must never receive or view User B's private order notifications.

Firebase Security Rules must enforce this.

---

## 48. Profile

Customers should have a profile containing:

- First name
- Last name
- Email
- Phone number
- Delivery address
- Profile picture if implemented

Customers can view their information.

---

## 49. Edit Profile

Customers can update appropriate profile information.

Editable fields include:

- First name
- Last name
- Phone number
- Delivery address
- Profile picture

Email/password changes should use the appropriate Firebase Authentication process.

---

## 50. Admin Dashboard

The admin dashboard should provide an overview of the store.

The dashboard should show:

- Number of orders
- Number of products sold
- Pending orders
- Refund requests
- Low-stock products
- Recent orders

The project does not currently require:

- Today's sales
- Weekly sales
- Monthly sales
- Sales graphs
- Revenue analytics

These can be added later if required.

---

## 51. Admin Product Management

Administrators can create new products.

Product creation should support:

- Product name
- Brand
- Description
- Price
- Product images
- Available colors
- Available sizes
- Stock per size/color combination
- Product availability

---

## 52. Admin Product Editing

Administrators can edit existing products.

They should be able to modify:

- Product name
- Brand
- Description
- Price
- Images
- Colors
- Sizes
- Stock
- Availability

Changes should be reflected in the customer product catalog.

---

## 53. Admin Product Deletion

Administrators can delete products.

Deletion should require appropriate confirmation.

The application should avoid accidentally deleting products through a single accidental tap.

If historical orders depend on a product, the implementation should consider whether a soft-delete/archive approach is more appropriate than permanently deleting the product data.

Historical order records should remain understandable even if a product is no longer available for sale.

---

## 54. Admin Product Images

Administrators can add product images.

The application should support the product image structure required by the project.

Some products may be preloaded with images so the APK does not appear empty during demonstration.

Administrators must still be able to add or update product images.

---

## 55. Preloaded/Demo Products

The application should include some preloaded/demo products for presentation purposes.

The reason is to ensure that when the teacher installs the APK, the application immediately demonstrates:

- Product browsing
- Search
- Filtering
- Product details
- Ratings
- Cart functionality
- Checkout

The application should not appear completely empty on first installation.

The preloaded products should use the same product structure as normal products whenever practical.

---

## 56. Admin Inventory Management

Administrators can manage inventory.

Inventory must respect the product's:

- Size
- Color
- Quantity

Example:

    Nike
    Jordan 3

    Red:
    Size 8  → 5
    Size 9  → 3
    Size 10 → 0

    Black:
    Size 8  → 4
    Size 9  → 2
    Size 10 → 6

---

## 57. Stock Updates During Orders

When an order is successfully placed, the appropriate inventory must be updated.

Example:

    Before:
    Jordan 3
    Red
    Size 9
    Stock = 5

    Customer buys:
    Quantity = 2

    After:
    Stock = 3

The application must prevent overselling.

Inventory operations should be designed carefully to avoid two customers purchasing the same final stock simultaneously.

The final implementation should use an appropriate Firebase transaction or atomic operation where necessary.

---

## 58. Low Stock

The admin dashboard should be able to identify products or variants with low stock.

The exact low-stock threshold can be defined in the application configuration.

Example:

    Stock ≤ 5

may be considered low stock.

The threshold should not be hard-coded in multiple places.

---

## 59. Authentication and Authorization

Authentication answers:

    Who is this user?

Authorization answers:

    What is this user allowed to do?

Both are required.

Customers should only access customer functionality.

Administrators should access administrative functionality.

The Flutter UI alone must not be treated as the security mechanism.

Firebase Security Rules and appropriate backend/authentication mechanisms must enforce authorization.

---

## 60. Customer Data Security

Customers must only be able to access their own private information.

This includes:

- Profile
- Cart
- Orders
- Notifications
- Refund requests
- Reviews where applicable

A customer must not be able to change their user role through the client application.

---

## 61. Admin Data Security

Administrative data must not be accessible to normal customers.

Examples include:

- All customer orders
- Refund requests from other customers
- Inventory management
- Product management
- Administrative dashboard data
- Other administrative information

Firebase Security Rules must prevent unauthorized access even if someone attempts to manipulate the application client.

---

## 62. Validation

The application should validate user input before submitting data.

Examples:

- Required registration fields
- Valid email
- Password requirements
- Password confirmation
- Phone number
- Address
- Product selection
- Size
- Color
- Quantity
- Refund reason
- Review rating

Validation should occur in the UI for user experience and should also be enforced by backend/security logic where necessary.

---

## 63. Error Handling

The application should gracefully handle:

- Network errors
- Firebase errors
- Authentication errors
- Missing data
- Product no longer available
- Insufficient stock
- Failed order creation
- Failed refund request
- Failed profile update

The user should receive a clear message rather than seeing raw technical errors.

---

## 64. Loading and Processing States

Asynchronous operations should provide appropriate loading states.

Examples:

- Logging in
- Registering
- Loading products
- Adding to cart
- Updating cart
- Placing order
- Updating profile
- Submitting refund
- Submitting review
- Updating admin data

Buttons should not allow accidental repeated submissions while an operation is processing.

---

## 65. Firebase Data Ownership

Firebase data should be associated with the appropriate user.

For example:

    Customer
        ↓
    User ID
        ├── Profile
        ├── Cart
        ├── Orders
        ├── Notifications
        └── Refund Requests

Administrative product and order data should be structured so authorized administrators can manage it without exposing it to normal customers.

The exact Firestore collection/document structure should be defined in the Firebase architecture documentation.

---

## 66. Order Data Snapshot

Orders should retain the information necessary to understand what was purchased at the time of the transaction.

For example, if a product's:

- Name
- Price
- Image
- Description

changes later, the historical order should still retain the relevant purchase information.

The order should not rely exclusively on the current product document to display historical order information.

---

## 67. Price Handling

The order should retain the price at the time of purchase.

If an administrator changes the product price later:

    Old Order:
    ₱2,500

should not automatically change to:

    ₱2,800

because the product price was changed.

Historical orders should preserve the original transaction price.

---

## 68. Cart and Product Changes

If a product's price or stock changes while it is already in a customer's cart, the checkout process must validate the current product state before creating the order.

The application should not blindly trust stale cart data.

The final order must use validated current information.

---

## 69. Order Creation Security

The customer application must not be trusted to determine sensitive final order values by itself.

The system should validate:

- Product
- Variant
- Stock
- Price
- Quantity
- Shipping fee
- Total

using trusted application/backend logic where appropriate.

The goal is to prevent a modified client from submitting an arbitrary price.

---

## 70. Payment Placeholder Architecture

The current payment implementation is not finalized.

The application should therefore separate payment-method selection from the actual payment-processing logic.

This will allow the payment implementation to be updated later when the instructor provides the final requirements.

Do not create fake successful online payments simply to simulate a real payment gateway.

---

## 71. Notification Generation Architecture

Notifications should be generated based on actual application events.

Example:

    Order status changed
        ↓
    Notification created
        ↓
    Customer sees notification

Avoid creating notifications simply because a screen was opened.

Notifications should represent actual events.

---

## 72. Admin Privileges

The administrator is the store manager.

The administrator can:

- Manage products
- Manage inventory
- View orders
- Update order statuses
- Review refunds
- Approve refunds
- Reject refunds
- View relevant customer delivery information
- View dashboard information

Normal customers cannot access these privileges.

---

## 73. No Seller Feature

Do not implement:

- Seller registration
- Seller application
- Seller approval
- Seller dashboard
- Seller profile
- Seller-specific product management

Trend Kicks is a single-store e-commerce application.

The administrator represents the store.

---

## 74. Feature Priority

The core required shopping flow is:

    Register/Login
          ↓
    Home
          ↓
    Browse/Search
          ↓
    Product Details
          ↓
    Select Variant
          ↓
    Add to Cart / Buy Now
          ↓
    Checkout
          ↓
    Payment
          ↓
    Place Order
          ↓
    Order Confirmation
          ↓
    Order Tracking

Supporting functionality:

    Profile
    Order History
    Notifications
    Reviews
    Refund Requests

Administrative functionality:

    Admin Login
          ↓
    Admin Dashboard
          ├── Product Management
          ├── Inventory Management
          ├── Order Management
          └── Refund Management

---

## 75. Feature Implementation Principle

The AI must implement the documented functionality without unnecessarily complicating the application.

When multiple implementation approaches are possible:

- Follow the project documentation
- Prefer the simpler understandable solution
- Preserve security
- Preserve data integrity
- Avoid unnecessary dependencies
- Avoid unnecessary features
- Keep the architecture maintainable
- Keep the implementation compatible with Flutter and Firebase

Do not add major features that are not documented unless explicitly requested.

---

## 76. Future-Change Principle

Some project requirements are intentionally left open for later clarification.

The most important currently pending area is online payment processing.

The implementation should therefore avoid tightly coupling the application to an unconfirmed payment provider or workflow.

When the instructor provides the final payment requirements, the payment-related portion should be replaceable or extendable without rewriting unrelated parts of the application.

---

## 77. Final Feature Principle

Trend Kicks is a single-brand/single-store shoe e-commerce application.

The application must provide a complete customer shopping experience:

    Account
      ↓
    Browse
      ↓
    Search
      ↓
    Filter
      ↓
    Product Details
      ↓
    Cart
      ↓
    Checkout
      ↓
    Payment
      ↓
    Order
      ↓
    Tracking
      ↓
    Delivery
      ↓
    Review

It must also provide store management:

    Admin
      ↓
    Dashboard
      ↓
    Products
      ↓
    Inventory
      ↓
    Orders
      ↓
    Refund Requests

Security, user privacy, stock accuracy, and order data integrity are required throughout the application.

The AI must treat this document as the functional specification for Trend Kicks and must follow it when implementing application features.