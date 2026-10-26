# Trend Kicks — Data Models Specification

## 1. Purpose

This document defines the data models used by the Trend Kicks Flutter e-commerce application.

The data models describe:

- What information the application stores.
- How information is represented inside Flutter.
- What information is stored in Cloud Firestore.
- How different pieces of data are related.
- What information is required for customers, products, carts, orders, reviews, refunds, notifications, payments, and administration.

The data models must remain consistent with:

- `00_RULES.md`
- `01_FEATURES.md`
- `02_UI_UX.md`
- `03_FIREBASE.md`
- `05_ARCHITECTURE.md`

The AI must use this document as the source of truth when creating or modifying Dart data models.

---

## 2. Data Storage Overview

Trend Kicks will use Firebase services for application data.

The main data systems are:

- Firebase Authentication
- Cloud Firestore
- Firebase Storage

Firebase Authentication handles:

- Account authentication
- Login
- Registration
- Logout
- Authentication state

Cloud Firestore handles structured application data such as:

- Users
- Products
- Product variants
- Carts
- Orders
- Reviews
- Refund requests
- Notifications

Firebase Storage handles uploaded files such as:

- Product images
- Profile images

The actual image file should not be stored directly inside a Firestore document.

Instead:

- Image file → Firebase Storage
- Image URL/reference → Firestore

---

## 3. General Data Model Rules

All data models should:

- Have a unique identifier where appropriate.
- Use consistent field names.
- Support Firestore serialization and deserialization.
- Use appropriate Dart data types.
- Avoid storing unnecessary duplicated information.
- Preserve historical information when required.
- Use timestamps where appropriate.

The AI must not create fields that are not required unless there is a clear technical reason.

---

## 4. User Model

The application will use one primary `UserModel`.

There will not be a separate `AdminModel`.

An administrator is still represented as a user, but has a different role.

The user model should contain:

- User ID
- Full name
- Email
- Phone number
- Address
- Profile photo URL
- Role
- Created date
- Updated date

---

## 5. User ID

Each user must have a unique `userId`.

The user ID should correspond to the Firebase Authentication user identity where appropriate.

The user ID is used to connect:

- User
- Cart
- Orders
- Reviews
- Refund requests
- Notifications

Customers must only be able to access their own protected user-related data.

---

## 6. Full Name

The user's full name should be stored as a dedicated field.

Example:

- `fullName`

The UI may display this as:

- Full Name
- Name

The data model should use `fullName` consistently.

---

## 7. Email

The user model should store the user's email address.

Example:

- `email`

The email is associated with the user's Firebase Authentication account.

The application should not allow unauthorized users to modify another user's email or account information.

---

## 8. Phone Number

The user model should contain:

- `phoneNumber`

This is used for customer contact and delivery information.

The phone number should also be preserved inside an order when necessary because an order represents the information used during that purchase.

---

## 9. Saved Address

Each user will have one saved/default delivery address.

The address is intended to make checkout easier.

The customer can change the address when placing an order.

The user does not need a list of multiple saved addresses.

The model may contain:

- `address`

The address used by an order must be stored separately in the order data so that changing the user's current address does not modify old orders.

---

## 10. Profile Photo

The user model may contain:

- `profilePhotoUrl`

The actual image is stored in Firebase Storage.

Firestore stores the URL/reference needed by Flutter to display the image.

If the user has no profile image, the application should support a default profile image/avatar.

---

## 11. User Role

The user model contains:

- `role`

Expected roles are:

- `customer`
- `admin`

Newly registered users should automatically receive the `customer` role.

Customers must not be allowed to change their own role.

Admin authorization must be protected through Firebase Security Rules and appropriate backend/database controls.

---

## 12. User Timestamps

The user model should contain:

- `createdAt`
- `updatedAt`

`createdAt` represents when the account was created.

`updatedAt` represents when the user information was last modified.

---

## 13. Product Model

A product represents a shoe sold through the Trend Kicks store.

The product model should contain:

- Product ID
- Brand
- Model
- Edition
- Description
- Category
- Main image URL/reference
- Adult price
- Kids price
- Product variants
- Average rating
- Review count
- Availability
- Created date
- Updated date

---

## 14. Brand

The `brand` field represents the actual shoe brand.

Trend Kicks is the store, not the shoe manufacturer.

Examples of possible brands include:

- Nike
- Jordan
- Adidas
- New Balance
- Puma

The brand should not be replaced with `Trend Kicks` unless the actual product is a Trend Kicks-branded product.

---

## 15. Product Model Name

The `model` field identifies the shoe model.

Examples:

- Jordan 3
- Air Max 90
- Ultraboost
- 550

The model should remain separate from the edition.

---

## 16. Product Edition

The `edition` field identifies a specific edition, release, or variation name of the product.

Examples:

- Retro Red
- Black White
- Anniversary Edition
- Classic

The application should keep:

- Brand
- Model
- Edition

as separate pieces of information.

Example:

- Brand: Jordan
- Model: Jordan 3
- Edition: Retro Red

---

## 17. Product Description

The product model should contain:

- `description`

The description provides additional information about the shoe.

It may contain:

- Materials
- Design information
- Intended use
- Product details
- Other relevant information

The description is displayed on the product detail screen.

---

## 18. Product Categories

Each product should have a category.

The initial categories are:

- Running
- Sneakers
- Sport
- Casual

The category is used for:

- Filtering
- Browsing
- Product organization

The data model should allow the category to be stored consistently.

---

## 19. Product Image

For the initial implementation, each product will use one main/front product image.

The product model should contain an image URL/reference such as:

- `imageUrl`

The actual image file should be stored in Firebase Storage when it is uploaded by an administrator.

Preloaded/demo products may reference local Flutter assets when appropriate.

---

## 20. Product Pricing

Product pricing will use separate pricing for:

- Adult sizes
- Kids sizes

The product model should contain:

- `adultPrice`
- `kidsPrice`

Generally, adult sizes will use the standard product price.

Kids sizes will normally have a lower price.

The exact prices are controlled by the administrator.

---

## 21. Product Variant Model

A product variant represents a specific combination of:

- Size
- Color

Each variant must have its own stock quantity.

The variant model should contain:

- Variant ID
- Size
- Color
- Stock

---

## 22. Variant Example

Example product:

Jordan 3 — Retro Red

Possible variants:

- Size 8 / Red / Stock 3
- Size 9 / Red / Stock 5
- Size 10 / Red / Stock 2
- Size 8 / Black / Stock 4
- Size 9 / Black / Stock 0

Each combination is treated as its own inventory quantity.

---

## 23. Variant Stock

Stock must be tracked at the variant level.

The system must not treat the entire product as having one generic stock number.

For example:

If:

- Size 9 / Red = 5

then a customer cannot purchase:

- 6 units of Size 9 / Red

The application should prevent the quantity from exceeding available stock.

The backend/security logic must also protect against stock manipulation.

---

## 24. Product Availability

The product model should contain an availability state.

Example:

- `isAvailable`

This allows administrators to temporarily make a product unavailable.

A product can be unavailable even if inventory information still exists.

When a product is unavailable, customers should not be able to purchase it.

---

## 25. Product Rating

The product should contain an automatically calculated average rating.

Example:

- `averageRating`

The rating should be calculated from customer reviews.

Administrators should not manually enter the average rating.

---

## 26. Review Count

The product may contain:

- `reviewCount`

This represents the number of eligible reviews associated with the product.

The review count should be updated when reviews are created or removed according to the application's review rules.

---

## 27. Product Timestamps

Products should contain:

- `createdAt`
- `updatedAt`

`createdAt` represents when the product was created.

`updatedAt` represents the latest modification to the product.

---

## 28. Cart Model

The cart belongs to an authenticated customer.

The cart should be associated with:

- User ID

The cart contains the customer's selected products before checkout.

The cart should support:

- Adding products
- Removing products
- Changing quantities
- Validating stock
- Calculating subtotal

---

## 29. Cart Item Model

Each cart item should contain enough information to identify the exact product variant being purchased.

The cart item should contain:

- Product ID
- Variant ID
- Size
- Color
- Quantity
- Price
- Product image

---

## 30. Cart Price

The cart should represent the current product price when the item is added or updated.

The final historical purchase price must be stored separately inside the order.

This prevents later product price changes from changing the price of an already completed order.

---

## 31. Cart Stock Validation

Before checkout, the system must verify that the selected quantity is still available.

Example:

Customer adds:

- Size 9
- Red
- Quantity 5

If the available stock becomes 3 before checkout, the application must prevent the customer from purchasing 5.

The customer should be informed that the available stock has changed.

---

## 32. Order Model

An order represents a completed purchase transaction.

The order model should contain:

- Order ID
- User ID
- Order items
- Shipping information
- Payment information
- Subtotal
- Shipping fee
- Total
- Order status
- Created date
- Updated date

---

## 33. Order ID

Every order must have a unique:

- `orderId`

The ID can be used to identify the order in:

- Customer order history
- Order details
- Notifications
- Refund requests
- Reviews
- Admin order management

---

## 34. Order User ID

Each order must contain:

- `userId`

This identifies the customer who placed the order.

Customers must only be able to read their own orders.

Administrators with the appropriate permissions can access order information for store management.

---

## 35. Order Items

An order may contain multiple items.

Each order item should preserve:

- Product ID
- Variant ID
- Product name/details needed for historical display
- Brand
- Model
- Edition
- Size
- Color
- Quantity
- Price paid
- Image reference where appropriate

The order item should preserve the information needed to display the historical purchase correctly.

---

## 36. Historical Product Price

The order item must store the actual price paid at the time of purchase.

Example:

Initial product price:

- ₱3,000

Customer purchases it.

Later, admin changes the product price:

- ₱3,500

The old order must continue showing:

- ₱3,000

If the same customer purchases the same product again after the price change, the new order uses:

- ₱3,500

Historical orders must never be recalculated using the current product price.

---

## 37. Order Subtotal

The order should contain:

- `subtotal`

The subtotal represents the total cost of purchased products before shipping.

It should be calculated from the order items and their historical purchase prices.

---

## 38. Shipping Fee

The order should contain:

- `shippingFee`

The shipping fee must be included in the final order total.

Customers should be able to see the shipping cost before confirming the order.

---

## 39. Order Total

The order should contain:

- `total`

The total should represent:

- Subtotal
- Plus shipping fee
- Plus any other approved applicable charges

The final total should be preserved inside the order.

---

## 40. Shipping Information

Because Trend Kicks uses delivery only, an order should contain delivery information.

The order should preserve:

- Recipient name
- Phone number
- Delivery address
- Shipping fee
- Shipping information/status where applicable

The customer can change their address during checkout.

Once the order is created, the order retains the address used for that purchase.

---

## 41. Payment Model

Payment information should be represented in the order or through an appropriate payment model.

The payment information should support:

- Payment method
- Payment status
- Transaction/reference ID where applicable
- Amount
- Payment date

---

## 42. Payment Methods

The supported payment methods are:

- Cash on Delivery
- GCash
- Maya

The application should not claim that an online payment was successfully processed unless the configured payment system actually confirms the transaction.

---

## 43. Payment Status

Payment status should be represented consistently.

Possible states may include:

- Pending
- Paid
- Failed
- Cancelled

The exact status transitions should follow the payment implementation.

COD orders may have a payment status appropriate for payment being collected upon delivery.

---

## 44. Order Status

Orders should use consistent order statuses.

Initial statuses are:

- Pending
- Confirmed
- Preparing
- Shipped
- Delivered
- Cancelled

The status represents the current stage of the order.

---

## 45. Order Cancellation

Customers may cancel an order only while cancellation is permitted by the order status rules.

Once the order has reached:

- `Shipped`

the customer cannot cancel the order.

The application must enforce this rule through both application logic and appropriate backend/security controls where applicable.

---

## 46. Order Timestamps

Orders should contain:

- `createdAt`
- `updatedAt`

These timestamps help track when the order was created and last updated.

---

## 47. Review Model

A review represents customer feedback for a purchased product.

The review should contain:

- Review ID
- User ID
- User name
- Product ID
- Order ID
- Rating
- Review text
- Created date
- Updated date

---

## 48. Review Rating

The rating must be an integer from:

- 1
- 2
- 3
- 4
- 5

The product's average rating is calculated from its reviews.

Customers cannot submit ratings outside the supported range.

---

## 49. Review Eligibility

A customer can review a product only after the relevant order has been delivered/received according to the application's order rules.

The review must be connected to:

- User ID
- Product ID
- Order ID

This allows the system to determine whether the customer is eligible to review the product.

---

## 50. Review Editing

Customers may edit their own reviews.

When a review is edited:

- `updatedAt` should be updated.

The original creation time remains represented by:

- `createdAt`

Customers must not be able to edit another customer's review.

---

## 51. Review Images

Review images are not required for the initial implementation.

The initial review model will not require image fields.

If review images are added in the future:

- Actual image files should be stored in Firebase Storage.
- Firestore should store image URLs/references.

---

## 52. Refund Request Model

A refund request is associated with a specific item in an order.

The refund request should contain:

- Refund ID
- User ID
- Order ID
- Order item ID
- Product ID
- Reason
- Optional description
- Status
- Admin ID who reviewed it
- Admin response/reason
- Created date
- Reviewed date

---

## 53. Item-Specific Refunds

Refund requests must be item-specific.

Example:

An order contains:

- Jordan 3
- Nike Air Max
- Adidas shoe

If the Jordan 3 has a problem, the customer can request a refund for:

- Jordan 3

without automatically requesting a refund for the entire order.

The refund request must identify the exact order item.

---

## 54. Refund Reasons

The application should provide predefined refund reasons.

Initial reasons include:

- Wrong item received
- Damaged item
- Defective item
- Wrong size
- Item significantly different from description
- Other

The customer may provide an optional written explanation when appropriate.

---

## 55. Refund Status

Refund requests should use consistent statuses.

Initial statuses:

- Pending
- Approved
- Rejected

The initial status when the customer submits a request is:

- `Pending`

Only an authorized administrator can change the request to:

- `Approved`
- `Rejected`

---

## 56. Refund Review

The refund workflow is:

- Customer selects an item.
- Customer selects a predefined reason.
- Customer optionally provides an explanation.
- Customer submits the request.
- Request becomes `Pending`.
- Authorized admin reviews the request.
- Admin approves or rejects the request.
- Customer can view the updated status.

---

## 57. Refund Admin Information

When an administrator reviews a refund, the system should preserve:

- Admin ID
- Admin response/reason
- Reviewed date

This provides a record of which administrator reviewed the request.

---

## 58. Refund Images

Refund evidence images are not required for the initial implementation.

The refund model should not include photo evidence fields unless the feature is added later.

---

## 59. Notification Model

Notifications should remain simple.

The notification model should contain:

- Notification ID
- User ID
- Title
- Message
- Type
- Is read
- Created date

---

## 60. Notification Type

The `type` field can identify the reason for the notification.

Possible examples include:

- Order
- Refund
- Promotion
- System

Additional types may be added later if required.

---

## 61. Notification Read State

Each notification should contain:

- `isRead`

When the customer opens or marks a notification as read, the value can change from:

- `false`

to:

- `true`

---

## 62. Notification Related Data

Notifications may optionally contain a related identifier when navigation to a specific item is useful.

For example:

- Order notification → order ID
- Refund notification → refund ID

This field should remain optional so that simple notifications do not require unnecessary data.

---

## 63. Admin Data

There is no separate administrator data model.

Administrators use:

- `UserModel`

with:

- `role = admin`

This keeps the account structure simple.

---

## 64. Admin Authorization

The `role` field must not be treated as the only security mechanism inside Flutter.

Firebase Security Rules must protect administrative operations.

A customer must not be able to:

- Change their role to admin.
- Create products.
- Modify products.
- Modify stock.
- View all customer orders.
- Approve refunds.
- Reject refunds.
- Perform other administrative operations.

---

## 65. Product Management Data

Administrators need enough product data to manage:

- Brand
- Model
- Edition
- Description
- Category
- Image
- Adult price
- Kids price
- Variants
- Size
- Color
- Stock
- Availability

The product model must support these operations without requiring a separate seller model.

---

## 66. Seller Data

Trend Kicks does not use a marketplace seller system.

There is:

- No seller registration.
- No seller application.
- No seller approval.
- No seller dashboard.
- No seller ID.
- No seller product ownership.

Trend Kicks is the store.

Administrators manage the store's products and orders.

---

## 67. Wishlist Data

The application does not currently support a wishlist/favorites feature.

No wishlist model is required.

If the feature is added in the future, a dedicated model can be introduced.

---

## 68. Search and Filtering Data

Search and filtering should operate on existing product data.

A separate search model is not required.

Product filtering may use:

- Brand
- Category
- Size
- Color
- Price
- Rating
- Availability

The exact filters must follow `01_FEATURES.md`.

---

## 69. Rating Sorting

Product ratings should support sorting from:

- Highest rated
- Lowest rated

The rating used for sorting should come from the calculated product average rating.

---

## 70. Product Relationships

The main product relationship is:

- Product
  - Product variants
  - Reviews

A product may have:

- Many variants
- Many reviews

---

## 71. User Relationships

A user may have:

- One saved address
- One cart
- Many orders
- Many reviews
- Many refund requests
- Many notifications

An admin is still represented by the same user model.

---

## 72. Order Relationships

An order belongs to:

- One user

An order contains:

- One or more order items

An order item references:

- One product
- One product variant

An order may have:

- Refund requests
- Related notifications
- Reviews associated with its delivered items

---

## 73. Refund Relationships

A refund request belongs to:

- One user
- One order
- One order item
- One product

A refund request may be reviewed by:

- One authorized admin

---

## 74. Review Relationships

A review belongs to:

- One user
- One product
- One order

This relationship allows the system to verify that the review is associated with a legitimate purchase.

---

## 75. Data Duplication for Historical Records

Some information may intentionally be duplicated inside orders.

For example, an order item may store:

- Product name
- Brand
- Model
- Edition
- Price
- Size
- Color

This is intentional.

The purpose is to preserve the information that existed when the customer purchased the product.

The order should not depend entirely on the current product document.

---

## 76. Product Changes After Purchase

If an administrator changes:

- Product name
- Product price
- Product image
- Product description
- Product availability

existing orders must retain the information needed to correctly represent the original purchase.

The current product document represents the current product.

The order represents the historical transaction.

---

## 77. Stock Changes

Stock belongs to product variants.

For example:

```text
Product:
Jordan 3

Variant:
Size 9 / Red

Stock:
