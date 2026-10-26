# Trend Kicks — Firebase Specification

## 1. Purpose

This document defines how Firebase should be used for the Trend Kicks Flutter e-commerce application.

Firebase will provide the backend services required for:

- User authentication
- User data
- Product data
- Product variants
- Inventory
- Shopping carts
- Orders
- Reviews
- Refund requests
- Notifications
- Product images
- Profile pictures
- Admin access control

The implementation must follow this document together with:

- 00_RULES.md
- 01_FEATURES.md
- 02_UI_UX.md

The AI must not invent a completely different Firebase structure without a documented reason.

---

## 2. Firebase Services

The project will use Firebase services that are appropriate for the application's requirements.

The planned services are:

- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Messaging

The project should avoid unnecessary Firebase services.

Do not introduce paid third-party services unless explicitly approved by the developer.

---

## 3. Firebase Authentication

Firebase Authentication will handle customer login and registration.

The primary authentication method will be:

- Email and password

Users must have an account to use account-specific functionality.

Authentication should be used for:

- Registration
- Login
- Logout
- Maintaining the user's authenticated session
- Identifying the current user

The application must not store plaintext passwords in Firestore.

Passwords must be handled by Firebase Authentication.

---

## 4. Registration

When a customer registers, the application should:

- Create the Firebase Authentication account
- Create the corresponding user document in Firestore
- Store the user's required profile information
- Automatically log the user in after successful registration

Required registration information:

- First name
- Last name
- Email
- Password
- Confirm password
- Phone number
- Delivery address

Profile picture is optional.

If a profile picture is provided, it should be stored using Firebase Storage.

---

## 5. User Document

Customer-specific profile information should be stored in Firestore.

The user document should contain information conceptually similar to:

- uid
- firstName
- lastName
- email
- phoneNumber
- address
- profileImageUrl
- role
- createdAt
- updatedAt

The Firebase Authentication UID should be used as the user's primary identifier.

The user's email should correspond to the authenticated account.

---

## 6. User Roles

The application has two main roles:

- customer
- admin

Normal users must receive the customer role.

The application must not allow a normal user to choose "admin" during registration.

Users must never be able to promote themselves to admin through the Flutter application.

---

## 7. Admin Account Creation

Admin accounts will be created manually.

The registration screen must never provide an option such as:

- Register as Admin
- Create Admin Account
- Select Account Type

Admin privileges must be assigned manually through the appropriate Firebase/admin configuration process.

The AI must not implement a customer-facing method for creating admin accounts.

---

## 8. Admin Authorization

Admin access must not depend only on hiding admin buttons in the UI.

The application must use actual authorization controls.

Firebase Security Rules must prevent normal customers from performing admin-only operations.

Admin-only functionality includes:

- Adding products
- Editing products
- Deleting products
- Managing product images
- Managing sizes
- Managing colors
- Managing stock
- Viewing all orders
- Updating order statuses
- Reviewing refunds
- Approving refunds
- Rejecting refunds

---

## 9. Cloud Firestore

Cloud Firestore will be the primary database for application data.

Firestore should store structured application information such as:

- Users
- Products
- Product variants
- Carts
- Orders
- Reviews
- Refund requests
- Notifications

The database should be structured so that customer data is separated logically and access can be controlled securely.

---

## 10. Firestore Collection Structure

The initial Firestore structure should be based on these main collections:

- users
- products
- carts
- orders
- reviews
- refund_requests
- notifications

The AI may use subcollections where they provide a clear security or data-organization benefit.

Do not create unnecessary collections.

---

## 11. Users Collection

The `users` collection stores customer profile information.

Conceptually:

users/{uid}

Example fields:

- uid
- firstName
- lastName
- email
- phoneNumber
- address
- profileImageUrl
- role
- createdAt
- updatedAt

The document ID should normally correspond to the Firebase Authentication UID.

---

## 12. User Data Security

A customer should only be able to access their own private profile information.

A customer must not be able to:

- Read another customer's private profile
- Modify another customer's profile
- Change another user's role
- Change their own role to admin

Admin access should follow the documented administrator permissions.

---

## 13. Products Collection

The `products` collection stores the shoes sold by Trend Kicks.

A product should contain information conceptually similar to:

- productId
- name
- brand
- description
- price
- images
- rating
- reviewCount
- variants
- isAvailable
- createdAt
- updatedAt

The exact implementation of variants may use nested structures or a separate collection/subcollection depending on the final architecture.

The important requirement is that inventory must be tracked by size and color.

---

## 14. Supported Brands

The initial store will focus on three brands:

- Nike
- Puma
- Adidas

The brand should be stored as product data rather than hard-coded into every UI screen.

If additional brands are added later, the architecture should not require rewriting the entire application.

---

## 15. Product Images

Product images should be stored using Firebase Storage when they are uploaded dynamically.

Firestore should store the corresponding image URLs or references required by the application.

The application will also contain preloaded/demo product images so the APK does not appear empty when demonstrated.

The preloaded/demo products should be available when the teacher installs the application.

---

## 16. Admin Product Image Management

Administrators should be able to:

- Add product images
- Upload multiple images
- Replace product images
- Delete product images

The application should not require the admin to manually edit Firebase URLs.

The admin interface should handle image selection and upload.

---

## 17. Product Variants

Inventory must be variant-based.

A product may have multiple combinations of:

- Color
- Size

Example:

Jordan 3

- Red / Size 8 / Stock 3
- Red / Size 9 / Stock 5
- Black / Size 8 / Stock 2
- Black / Size 9 / Stock 0

The application must treat these combinations as separate inventory quantities.

---

## 18. Variant Identification

Each product variant should have a unique identifier.

A variant should conceptually contain:

- variantId
- productId
- color
- size
- stock
- isAvailable

The exact field names may be adjusted to match the final Dart models.

The important requirement is that each size/color combination can have its own stock.

---

## 19. Stock Validation

Stock must be validated before an item can be added to the cart.

Example:

If:

Jordan 3 / Red / Size 9

has:

Stock = 5

The customer cannot add quantity 6.

The UI should communicate that insufficient stock is available.

---

## 20. Stock Enforcement

Stock restrictions must not rely only on the Flutter UI.

The application must also protect inventory at the data/backend level.

A malicious or modified client must not be able to simply submit a larger quantity than the available stock.

The final implementation should use appropriate Firebase/backend validation and atomic operations where necessary.

---

## 21. Cart Collection

The user's cart must persist when the application is closed.

The cart should be associated with the authenticated user.

Conceptually:

carts/{uid}

The cart should contain the user's current cart items.

A cart item should contain information such as:

- productId
- variantId
- productName
- size
- color
- price
- image
- quantity

The final architecture may normalize some of this data differently.

---

## 22. Cart Ownership

A customer must only be able to access their own cart.

A customer must not:

- Read another customer's cart
- Modify another customer's cart
- Delete another customer's cart

The Firebase Security Rules must enforce cart ownership.

---

## 23. Cart Persistence

The cart must remain available after:

- Closing the application
- Restarting the application
- Logging back into the same account

The cart should be associated with the user's account rather than only stored locally.

---

## 24. Cart Stock Validation

When the user views or updates the cart, the application should account for changes in stock.

For example:

A customer adds 5 units to their cart.

Later, only 3 remain available.

The application should detect the stock conflict before allowing the customer to complete the order.

The customer should be informed and required to adjust the quantity.

---

## 25. Orders Collection

Orders should be stored in the `orders` collection.

Each order should contain information conceptually similar to:

- orderId
- userId
- items
- subtotal
- shippingFee
- total
- shippingAddress
- paymentMethod
- orderDate
- status
- createdAt
- updatedAt

The final field names should follow the Dart data models.

---

## 26. Order Items

Each order should contain the individual products purchased.

An order item should preserve information such as:

- productId
- variantId
- productName
- size
- color
- quantity
- unitPrice
- image

This allows the order to preserve what the customer actually purchased.

---

## 27. Order Price Snapshot

When an order is created, the order should preserve the relevant product price at the time of purchase.

For example:

Product price at purchase:

₱5,000

Later, the admin changes the product price to:

₱6,000

The old order must still show:

₱5,000

The application must not calculate historical orders using the current product price.

---

## 28. Order Data Integrity

The customer application must not be trusted to determine sensitive order values.

Important values include:

- Product price
- Quantity
- Stock
- Shipping fee
- Order total
- User ID
- Order ownership
- Order status

The architecture should prevent a modified client from simply changing these values before submitting an order.

The final security design should use Firebase Security Rules and appropriate trusted backend logic where required.

---

## 29. Shipping Address Snapshot

When an order is created, the shipping address used for that order should be preserved with the order.

If the customer later changes their profile address, an old order should still show the original delivery address used when the order was placed.

---

## 30. Shipping Fee

The order should preserve the shipping fee applied when the order was placed.

The shipping fee should be included in the final order total.

The database should preserve the shipping information required to display historical orders accurately.

---

## 31. Order Status

The initial order status flow is:

- Pending
- Confirmed
- Preparing
- Shipped
- Delivered

Additional terminal states include:

- Cancelled

Refund requests should have their own status rather than replacing the main order status.

---

## 32. Order Status Permissions

Customers must not be able to arbitrarily change their order status.

For example, a customer must not be able to change:

Pending

to:

Delivered

Order status changes should be restricted to the appropriate admin/system operations.

---

## 33. Order Cancellation

Customers may cancel an order while cancellation is allowed.

Once the order has been shipped:

- The customer cannot cancel it.

The backend/security design must not rely solely on disabling the cancel button.

The actual operation must enforce the restriction.

---

## 34. Order Privacy

Customers should only be able to view their own orders.

A customer must not be able to query or view:

- Another customer's orders
- Another customer's delivery address
- Another customer's payment method
- Another customer's order items

Admins may access orders according to their authorized role.

---

## 35. Reviews Collection

Reviews should be stored in the `reviews` collection.

A review should contain information conceptually similar to:

- reviewId
- productId
- userId
- orderId
- orderItemId
- rating
- comment
- createdAt
- updatedAt

The order/item reference helps determine whether the customer is eligible to review the product.

---

## 36. Review Eligibility

A customer can review a product only after the relevant order has been delivered.

The customer should not be able to review a product from:

- Pending order
- Confirmed order
- Preparing order
- Shipped order
- Cancelled order

The final implementation should verify delivery status rather than relying only on the UI.

---

## 37. One Review Per Purchased Item

A customer should normally be able to create one review for a specific purchased order item.

The application should prevent duplicate reviews for the same eligible order item.

Customers may be allowed to edit their existing review.

---

## 38. Review Ratings

Ratings use a five-star system:

- 1 star
- 2 stars
- 3 stars
- 4 stars
- 5 stars

The product's displayed rating should be calculated from its reviews.

The application should avoid allowing users to directly modify a product's average rating.

---

## 39. Refund Requests Collection

Refund requests should be stored separately from normal orders.

The `refund_requests` collection should conceptually contain:

- refundRequestId
- orderId
- orderItemId
- userId
- reason
- description
- status
- createdAt
- reviewedAt
- reviewedBy

The exact fields may be adjusted by the final architecture.

---

## 40. Item-Specific Refunds

Refunds must be item-specific.

Example order:

- Jordan 3
- Puma RS-X
- Adidas Campus

If the Jordan 3 is damaged, the customer can request a refund for:

Jordan 3 only.

The entire order must not automatically become refundable.

The refund request must reference the specific order item.

---

## 41. Refund Reasons

The application should provide predefined refund reasons.

Initial options may include:

- Product arrived damaged
- Wrong product received
- Wrong size received
- Product does not match the order
- Defective product
- Other eligible reason

The final reason list may be changed later.

The reason should be stored with the refund request.

---

## 42. Refund Workflow

The refund workflow is:

Customer selects an eligible order item.

Customer selects a refund reason.

Customer submits the refund request.

The request receives:

Pending Review

The administrator reviews the request.

The administrator can:

- Approve
- Reject

The customer can then see the resulting refund status.

---

## 43. Refund Status

Initial refund statuses:

- Pending Review
- Approved
- Rejected

The refund status must be controlled by authorized operations.

Customers must not be able to change their own refund status.

---

## 44. Refund Authorization

Only authorized administrators may approve or reject refund requests.

Customers must not be able to:

- Approve refunds
- Reject refunds
- Change refund status
- Modify another user's refund request

The UI should hide unauthorized actions, but Firebase authorization must enforce the restriction.

---

## 45. Refund Payment Processing

The exact real-money refund mechanism is currently pending instructor clarification.

The database and application architecture should therefore separate:

- Refund request
- Refund decision
- Actual payment/refund processing

Do not create a fake payment refund system that claims to have transferred money if no real payment gateway has been implemented.

The payment implementation can be updated later when the instructor provides the final requirements.

---

## 46. Notifications Collection

Notifications should be stored in Firestore.

Conceptually:

notifications/{notificationId}

A notification should contain information such as:

- notificationId
- userId
- title
- message
- type
- relatedOrderId
- isRead
- createdAt

---

## 47. Notification Ownership

Customers must only be able to access their own notifications.

A customer must never be able to read or modify another customer's notifications.

---

## 48. Notification Events

Notifications may be generated for events such as:

- Order confirmed
- Order preparing
- Order shipped
- Order delivered
- Order cancelled
- Refund approved
- Refund rejected

The final notification types should match the implemented features.

---

## 49. In-App Notifications

The application must support notifications inside the application.

The notification history should remain available after the user closes and reopens the application.

Firestore can be used to persist the notification records.

---

## 50. Push Notifications

Firebase Cloud Messaging may be used for device push notifications.

Push notifications should not be implemented through paid SMS services.

The project should avoid SMS-based notification systems.

If push notifications are implemented, they should use Firebase Cloud Messaging where appropriate.

---

## 51. Free/Available Service Requirement

The project is intended for a school application.

Do not introduce services that require the developer to pay for every notification or normal application operation unless explicitly approved.

In particular:

- Do not use SMS for order notifications.
- Do not require paid SMS verification.
- Do not introduce paid notification providers.
- Do not introduce paid third-party backend services without approval.

Firebase services should be used within the available free/appropriate usage limits for the project.

Firebase pricing and service limits may change over time, so the documentation must not assume that every Firebase feature is permanently free without limits.

---

## 52. Firebase Storage

Firebase Storage should be used for uploaded files that need cloud storage.

Initial use cases include:

- Product images
- Profile pictures

Storage paths should be organized logically.

Conceptually:

- products/{productId}/...
- users/{uid}/...

The exact path structure may be adjusted by the final architecture.

---

## 53. Product Image Security

Normal customers should not be able to arbitrarily modify product images.

Product image upload, replacement, and deletion should be restricted to authorized administrators.

Customers may read publicly available product images according to the application's requirements.

---

## 54. Profile Image Security

Users should only be able to modify their own profile picture.

A customer must not be able to replace another user's profile image.

---

## 55. Firebase Security Rules

Firebase Security Rules are a critical part of the application.

Rules must enforce authorization at the Firebase level.

Do not assume that Flutter UI restrictions provide security.

The rules should distinguish between:

- Unauthenticated users
- Authenticated customers
- Administrators

---

## 56. Unauthenticated Access

Unauthenticated users should only have access to information that is intentionally public.

Depending on the final implementation, this may include:

- Public product information
- Public product images

Unauthenticated users must not access private:

- User data
- Carts
- Orders
- Refund requests
- Notifications
- Private profile information

---

## 57. Customer Product Access

Customers should be able to read the product information necessary to shop.

Customers must not be able to modify product information.

Customers must not be able to:

- Change product price
- Change stock
- Change product name
- Change product description
- Delete products
- Add unauthorized products

---

## 58. Customer Cart Access

A customer may read and modify their own cart.

A customer must not access another user's cart.

The cart's ownership must be verified using the authenticated user's UID.

---

## 59. Customer Order Access

Customers may create orders through the approved order process and read their own orders.

Customers must not:

- Read another user's orders
- Modify another user's orders
- Change order status
- Change order totals
- Change another user's shipping address
- Modify historical order prices

---

## 60. Customer Review Access

Customers may create eligible reviews for products they purchased and received.

Customers may modify their own eligible reviews according to the application's rules.

Customers must not:

- Create fake reviews for products they never purchased
- Modify another user's review
- Change another user's rating

---

## 61. Customer Refund Access

Customers may:

- Create refund requests for eligible items
- View their own refund requests

Customers must not:

- View another user's refund requests
- Approve their own refund
- Reject their own refund
- Change their refund status
- Modify another user's refund request

---

## 62. Admin Product Permissions

Administrators may:

- Create products
- Edit products
- Delete products
- Upload product images
- Manage product variants
- Manage stock
- Manage availability

These permissions must be enforced through Firebase authorization.

---

## 63. Admin Order Permissions

Administrators may:

- View orders
- View order details
- View customer delivery information needed to fulfill orders
- Update order status

Administrators must not be able to silently rewrite historical order information in a way that corrupts the customer's original purchase record.

The order should preserve the original purchase snapshot.

---

## 64. Admin Refund Permissions

Administrators may:

- View refund requests
- Review refund requests
- Approve refund requests
- Reject refund requests

The system should record which administrator reviewed the request when appropriate.

---

## 65. Admin Data Visibility

Administrators may have broader visibility than customers because the administrator operates the Trend Kicks store.

However, the application should only expose information necessary for store management.

Do not expose unnecessary sensitive information.

---

## 66. User Logout

Logging out should use Firebase Authentication's sign-out functionality.

After logout:

- The user should no longer be considered authenticated.
- Protected screens should not remain accessible through normal navigation.
- User-specific data should not be shown to an unauthenticated session.

---

## 67. Authentication State

The application should listen to Firebase Authentication state changes where appropriate.

The application should be able to determine whether the user is:

- Not authenticated
- Authenticated as customer
- Authenticated as admin

The authentication state should control access to protected areas.

---

## 68. Account Deletion

If account deletion is implemented later, it must be designed carefully because user data may be referenced by:

- Orders
- Reviews
- Refund requests
- Notifications

Do not automatically delete historical business records simply because a user account is removed unless the final requirements explicitly define how this should work.

---

## 69. Timestamps

Important records should use server-side or appropriately trusted timestamps where possible.

Examples include:

- Account creation
- Product creation
- Product updates
- Order creation
- Order updates
- Review creation
- Refund requests
- Refund decisions
- Notifications

The application should avoid trusting arbitrary client-provided timestamps for sensitive operations.

---

## 70. Data Validation

Data should be validated before being stored.

Examples include:

- Required fields
- Valid rating values
- Valid quantities
- Valid prices
- Valid stock values
- Valid product references
- Valid order references
- Valid user ownership
- Valid refund references

Validation should exist at the appropriate application and backend/security levels.

---

## 71. Duplicate Orders

The application should be designed to reduce accidental duplicate orders.

For example:

- Disable repeated order submission while processing.
- Use loading states.
- Prevent multiple rapid submissions.
- Use appropriate backend/data validation.

The final architecture should consider how to avoid creating two orders from one user action.

---

## 72. Inventory Race Conditions

Inventory must account for situations where multiple customers attempt to purchase the same limited stock at approximately the same time.

Example:

Stock = 1

Customer A attempts to buy 1.

Customer B attempts to buy 1.

The system should not allow the inventory to become negative.

The final implementation should use appropriate atomic/transactional Firebase operations or trusted backend logic.

---

## 73. Price Integrity

The client must not be trusted to define the final product price.

If a product costs:

₱5,000

a modified client must not be able to submit:

₱1

and successfully create an order using that price.

The architecture should use trusted product data and appropriate validation.

---

## 74. Shipping Fee Integrity

The client should not be able to arbitrarily change the shipping fee.

The final shipping fee should come from the application's approved configuration/business logic.

The order should preserve the shipping fee used at purchase time.

---

## 75. Order Total Integrity

The final order total must be calculated from trusted values.

Conceptually:

Subtotal + Shipping Fee = Total

The customer should not be able to simply submit an arbitrary total.

The final implementation should validate the total using trusted data.

---

## 76. Payment Method

The currently supported payment methods are:

- Cash on Delivery
- GCash
- Maya

The exact online payment integration is currently pending instructor clarification.

The Firebase structure should therefore store the selected payment method without assuming a specific payment gateway implementation that has not yet been approved.

---

## 77. Payment Status

If payment processing is implemented later, payment status should be separated from order status.

For example:

Order status:

- Pending
- Confirmed
- Preparing
- Shipped
- Delivered

Payment status could be:

- Pending
- Paid
- Failed
- Refunded

Do not merge these concepts unnecessarily.

The exact payment fields may be finalized after the instructor provides the payment requirements.

---

## 78. Demo/Preloaded Data

The application should contain initial demo products so the APK can demonstrate the store immediately.

The demo data should include enough information to demonstrate:

- Product browsing
- Product details
- Sizes
- Colors
- Stock
- Cart
- Checkout
- Orders
- Reviews

The final implementation method for seeding demo data should be documented in the setup/architecture documentation.

---

## 79. No Seller System

Trend Kicks is a self-owned shoe store for this project.

There is no marketplace seller system.

Do not create:

- Seller registration
- Seller applications
- Seller dashboards
- Seller approval
- Multiple independent sellers

The administrators are responsible for managing Trend Kicks products and orders.

---

## 80. Firebase Architecture Principle

Firebase should support the application without making the Flutter code unnecessarily complicated.

Use a clear separation between:

- UI
- Models
- Firebase services
- Data access
- Business logic
- Authentication
- Authorization

The exact implementation will be defined in the architecture documentation.

---

## 81. AI Firebase Development Rules

When implementing Firebase functionality, the AI must:

- Read this document first.
- Follow the existing architecture.
- Avoid inventing duplicate Firebase services.
- Avoid creating unnecessary collections.
- Avoid putting all Firebase logic directly inside UI widgets.
- Reuse existing services when available.
- Tell the developer when a terminal command is required.
- Tell the developer when Firebase Console configuration is required.
- Never assume a Firebase configuration step was completed if it has not been confirmed.
- Never hard-code private credentials or secrets into the Flutter application.

---

## 82. Firebase Configuration Security

Do not place sensitive secrets directly into source code.

Do not create fake credentials.

Do not expose private server credentials inside the Flutter APK.

Firebase configuration files required by FlutterFire should be handled according to the normal Firebase/Flutter setup process.

Any truly sensitive server-side credentials must not be embedded in the client application.

---

## 83. Client vs Backend Trust

The Flutter application is a client.

The client must not be treated as inherently trustworthy.

Security-sensitive operations must be protected by:

- Firebase Authentication
- Firebase Security Rules
- Trusted backend logic where necessary
- Firestore transactions/atomic operations where appropriate

Do not assume that disabling a button makes an operation secure.

---

## 84. Data Ownership Principle

Whenever possible, user-owned data should be associated with the authenticated Firebase UID.

Examples:

- User profile
- Cart
- Orders
- Refund requests
- Notifications
- Reviews

Ownership should be verified rather than inferred from user-supplied IDs.

---

## 85. Final Firebase Structure

The initial logical structure is:

- users
  - {uid}

- products
  - {productId}

- carts
  - {uid}

- orders
  - {orderId}

- reviews
  - {reviewId}

- refund_requests
  - {refundRequestId}

- notifications
  - {notificationId}

Product variants may be stored inside product documents or as a dedicated subcollection depending on the final architecture.

The final implementation must preserve the required behavior regardless of the exact storage representation.

---

## 86. Relationship Between Documents

The Firebase implementation must work together with the other project documentation.

- 00_RULES.md defines the overall project rules.
- 01_FEATURES.md defines what the application must do.
- 02_UI_UX.md defines how the application should look and behave visually.
- 03_FIREBASE.md defines how Firebase should support the application.

Future documentation may define:

- Flutter architecture
- Data models
- Security details
- Setup procedures
- Master AI development instructions

The AI must read the relevant documents before implementing Firebase functionality.

---

## 87. Final Firebase Principle

Firebase should provide a secure, organized, and understandable backend for Trend Kicks.

The final application should:

- Authenticate users securely.
- Store user information appropriately.
- Store products and variant inventory.
- Persist shopping carts.
- Store historical orders accurately.
- Preserve purchase prices.
- Track product reviews.
- Support item-specific refund requests.
- Store in-app notifications.
- Support administrator product and order management.
- Restrict administrator functions to authorized users.
- Prevent customers from accessing other customers' private data.
- Protect stock from invalid quantities and race conditions.
- Avoid trusting client-provided prices and totals.
- Avoid unnecessary paid services.
- Keep the Firebase implementation understandable and maintainable.

The AI must prioritize data integrity and authorization alongside functionality.

A feature that works visually but allows unauthorized Firebase access is not considered correctly implemented.


