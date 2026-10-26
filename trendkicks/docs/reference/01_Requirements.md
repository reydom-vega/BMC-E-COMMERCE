# Trend Kicks — Application Requirements

## 1. Application Overview

Trend Kicks is a mobile shoe e-commerce application developed using Flutter and Firebase.

The primary deliverable is an Android APK.

The application allows customers to browse and purchase shoes, manage their accounts, maintain a shopping cart, place orders, track order status, request refunds, and submit product reviews.

The application also provides an administrator system for managing products, inventory, orders, and refund requests.

The application must contain preloaded shoe products so that it is immediately usable after installation and is not presented as an empty store.

Trend Kicks is a **single-store/single-brand e-commerce application**.

It is not a multi-vendor marketplace.

---

# 2. User Roles

The application will have two primary user roles:

## Customer

Customers can:

* Register an account
* Log in
* Log out
* Manage their profile
* Browse shoes
* Search shoes
* Filter shoes
* Sort shoes
* View product details
* Select shoe size
* Select shoe color
* Add shoes to cart
* Purchase shoes
* View order confirmation
* View order history
* Track order status
* Cancel eligible orders
* Request refunds
* Submit product ratings and reviews
* Receive in-app notifications

## Administrator

Administrators can:

* Log in to an administrator account
* Add shoes
* Edit shoes
* Delete shoes
* Manage product information
* Manage product images
* Manage inventory
* View customer orders
* Update appropriate order statuses
* View the number of orders
* View the number of products sold
* Review refund requests
* Accept or reject refund requests

Administrator permissions must be separate from normal customer permissions.

---

# 3. Seller System — Not Required

Trend Kicks is not a marketplace.

The application does not require:

* Seller registration
* Seller applications
* Seller approval
* Seller accounts
* Seller dashboards
* Seller product management
* Seller-specific storefronts
* Seller payouts
* Seller commissions
* Multi-vendor functionality

All products are managed by the Trend Kicks administrator.

Nike, Puma, and Adidas are product brands carried by Trend Kicks. They are not sellers.

---

# 4. Registration

The application must provide a registration system.

A customer must be able to create an account using:

* Email
* Password
* First name
* Last name
* Phone number
* Delivery address

A profile picture may also be added.

The registration process must use Firebase Authentication.

Additional customer information should be stored using the application's Firebase data storage system.

---

# 5. Login

The application must provide a login screen.

Customers must be able to log in using:

* Email
* Password

Only authenticated users should be able to access account-specific functionality.

The application should properly handle:

* Invalid credentials
* Loading state
* Authentication errors
* Successful authentication
* Logout

---

# 6. Customer Profile

Customers must have a profile containing their account information.

The profile may contain:

* Email
* First name
* Last name
* Phone number
* Delivery address
* Profile picture

Customers must be able to edit their profile information.

Profile information should be used where appropriate during ordering and delivery.

---

# 7. Product Catalog

The application must contain a shoe product catalog.

The initial catalog will contain products from:

* Nike
* Puma
* Adidas

The application must include preloaded products so that the store contains usable content immediately after installation.

The administrator must also be able to add additional products after installation.

Each shoe product should support information including:

* Product ID
* Product name
* Brand
* Short description
* Price
* Product image
* Available sizes
* Available colors
* Stock
* Average rating
* Number of reviews

The exact database representation will be documented separately.

---

# 8. Product Images

The application must support product images.

The initial products will use preloaded images so the application is not empty when demonstrated.

Administrators must also be able to add images when creating or managing products.

Uploaded product images should use the appropriate Firebase storage mechanism.

The initial bundled assets and administrator-uploaded images must be handled appropriately without creating conflicting product-image systems.

---

# 9. Product Browsing

Customers must be able to browse available shoes.

The browsing experience should allow customers to view relevant information such as:

* Product image
* Product name
* Brand
* Price
* Rating
* Other relevant product information

The browsing experience must follow the provided Figma design.

---

# 10. Brand Filtering

Customers must be able to filter products by brand.

The initial filters are:

* All
* Nike
* Puma
* Adidas

Selecting a brand should display the products belonging to that brand.

The filtering system should allow additional brands to be supported in the future.

---

# 11. Product Search

Customers must be able to search for shoes by product name.

The search system should support partial-name searching where practical.

For example, searching:

`Jordan`

should allow products such as:

* Jordan 2
* Jordan 11
* Jordan 12
* Jordan 13

to appear in the results.

The purpose is to help customers discover related products even when they do not remember the exact product name.

---

# 12. Product Sorting

Customers must be able to sort products by rating.

The initial sorting options are:

* Highest rated
* Lowest rated

Additional sorting methods are not currently required.

---

# 13. Product Details

Customers must be able to open a product and view its detailed information.

The product details screen should contain relevant information including:

* Product name
* Brand
* Description
* Price
* Product images
* Available colors
* Available sizes
* Stock availability
* Rating
* Number of reviews
* Add to Cart functionality
* Purchase functionality

The product details interface must follow the provided Figma design.

If the Figma design does not contain a required feature, the feature must still be implemented using the established visual style.

---

# 14. Product Variants

Shoes must support product variants based on:

* Size
* Color

Customers must select the appropriate variant before purchasing when required.

Inventory should be associated with the appropriate variant.

Customers must not be able to purchase unavailable variants.

---

# 15. Shopping Cart

Customers must be able to add shoes to their cart.

A cart item should preserve the selected:

* Product
* Size
* Color
* Quantity
* Price

Customers must be able to:

* Add items
* Increase quantity
* Decrease quantity
* Remove items
* View cart contents
* View item totals
* View the overall cart total
* Proceed to checkout

The cart must persist between application sessions.

For example:

```text
Customer adds shoe
        ↓
Closes application
        ↓
Opens application later
        ↓
Shoe remains in cart
```

The cart must be associated with the authenticated customer.

---

# 16. Checkout

Customers must be able to proceed from their cart to checkout.

The checkout process must display relevant order information before submission.

The checkout should include:

* Ordered products
* Selected sizes
* Selected colors
* Quantities
* Product totals
* Shipping fee
* Overall total
* Shipping address
* Customer information where appropriate
* Payment method

The shipping fee must be displayed separately.

The shipping fee must also be included in the final order total.

---

# 17. Shipping

Customers must provide a delivery address.

The customer profile should contain a default delivery address that can be used during checkout.

A shipping fee must be applied to the order.

The customer must be able to see the shipping fee before confirming the order.

The shipping fee must be included in the final order total.

Advanced courier or GPS tracking is not required.

---

# 18. Payment

The application is intended to support:

* Cash on Delivery
* Online payment

The planned online payment methods are:

* GCash
* Maya

The exact online payment implementation is currently pending instructor-provided requirements.

The application must therefore be structured so the payment implementation can be added or modified later without requiring a major rewrite of unrelated functionality.

The application must not present a simulated or fake payment integration as a real GCash or Maya transaction.

---

# 19. Order Confirmation

After a successful checkout process, the customer must receive an order confirmation.

The confirmation should provide relevant information including:

* Order ID
* Products
* Selected variants
* Quantities
* Total price
* Shipping fee
* Shipping address
* Order date
* Payment method
* Initial order status

---

# 20. Order History

Customers must be able to view their previous orders.

Each order should provide relevant information including:

* Order ID
* Product name
* Size
* Color
* Quantity
* Total price
* Shipping address
* Order date
* Payment method
* Order status

Customers must only be able to view their own orders.

---

# 21. Order Status Tracking

Customers must be able to see the current status of their orders.

The initial order status flow is:

```text
Pending
   ↓
Confirmed
   ↓
Preparing
   ↓
Shipped
   ↓
Delivered
```

Orders may also become:

```text
Cancelled
```

Customers should be able to open an order and see its current stage.

This is application-level order status tracking.

Real-time courier GPS/location tracking is not required.

---

# 22. Order Cancellation

Customers must be able to cancel eligible orders.

Cancellation availability should depend on the current order status.

Customers must not be able to arbitrarily change an order's status.

The exact cancellation rules will be defined in `03_FEATURES.md` and `06_SECURITY.md`.

---

# 23. Refund Requests

Customers must be able to request a refund for an eligible order item.

The refund process is:

```text
Customer selects order item
        ↓
Request Refund
        ↓
Select predefined reason
        ↓
Send Request
        ↓
Admin Review
        ↓
Accept / Reject
```

The refund request should be associated with the relevant customer and order.

The application should provide predefined refund reasons.

The exact payment-provider refund behavior is currently pending instructor-provided payment requirements.

---

# 24. Product Reviews and Ratings

Authenticated customers must be able to submit product ratings and reviews.

Customers can rate a product using:

* 1 star
* 2 stars
* 3 stars
* 4 stars
* 5 stars

Customers may also provide a written review.

Reviews should be associated with:

* Customer
* Product
* Rating
* Review content
* Date/time

Products must display:

* Average rating
* Number of reviews

Only authenticated customers may submit reviews.

Customers do not currently need to have purchased the product before submitting a review.

---

# 25. Notifications

The application must provide in-app notifications.

Notifications should be associated with the appropriate customer.

Initial notification events include:

* Order confirmed
* Order preparing
* Order shipped
* Order delivered
* Order cancelled
* Refund approved
* Refund rejected

Phone push notifications are not currently required.

---

# 26. Administrator Product Management

Administrators must be able to create new products.

When adding a product, administrators should be able to provide:

* Product name
* Brand
* Description
* Price
* Product image
* Available colors
* Available sizes
* Stock

Administrators must also be able to edit existing product information.

Administrators must be able to delete products according to the application's data-management rules.

Unauthorized customers must not be able to modify products.

---

# 27. Administrator Image Management

Administrators must be able to add product images when creating or managing products.

The application will also contain preloaded product images for the initial catalog.

This ensures:

1. The application contains usable products immediately after installation.
2. The administrator can demonstrate adding new products.
3. The product system is not dependent entirely on bundled assets.

---

# 28. Administrator Inventory Management

Administrators must be able to manage product stock.

Inventory must account for available product variants such as:

* Size
* Color

Administrators must be able to update stock when managing products.

Customers must not be able to directly modify inventory.

---

# 29. Administrator Order Management

Administrators must be able to view customer orders.

Administrators must be able to update appropriate order statuses.

The normal order lifecycle is:

```text
Pending
↓
Confirmed
↓
Preparing
↓
Shipped
↓
Delivered
```

Administrators may also handle appropriate cancellation and refund operations according to the documented rules.

---

# 30. Administrator Dashboard

The administrator interface must display basic order and product-sales information.

The initial required statistics are:

* Number of orders
* Number of products sold

The following are not currently required:

* Sales today
* Sales this week
* Sales this month

These may be future enhancements but should not be implemented unless requested.

---

# 31. Authentication Requirements

Authentication is mandatory.

The application must contain:

* Registration
* Login
* Logout
* Authenticated customer access
* Administrator authentication

Account-specific information must be associated with the authenticated user's identity.

Authentication will use Firebase Authentication with email and password.

---

# 32. Data Persistence

Important application data must persist using Firebase/backend storage.

Data that should persist includes:

* User accounts
* Customer profile information
* Products
* Product variants
* Product stock
* Shopping carts
* Orders
* Reviews
* Ratings
* Notifications
* Refund requests
* Administrator-managed product information

The application must not rely solely on temporary in-memory data for information that needs to remain after the application is closed.

---

# 33. Initial Product Data

The application must contain preloaded products for demonstration purposes.

The initial products should represent:

* Nike
* Puma
* Adidas

The exact products, images, prices, sizes, colors, descriptions, and initial stock values will be documented separately.

The initial data should allow the teacher to install the APK and immediately browse a populated store without manually creating products first.

---

# 34. UI and Design Requirement

The application must follow the provided Figma design.

The Figma design is the primary visual reference for:

* Screen layouts
* Navigation
* Colors
* Typography
* Spacing
* Buttons
* Cards
* Product presentation
* Overall visual style

Required functionality takes priority over the absence of a feature in the Figma design.

If a required feature is not shown in Figma, the feature must be added using the established visual language of the design.

---

# 35. Responsive Layout Requirement

The primary target is Android APK.

The application should work reasonably across different Android screen sizes.

The application must avoid layouts that only work on one specific screen size.

Responsive Flutter layout practices should be used where practical.

Desktop and web optimization are not currently required.

---

# 36. Firebase Requirements

Firebase will be used as the backend platform.

The project is expected to use:

* Firebase Core for Firebase initialization
* Firebase Authentication for customer/admin authentication
* Cloud Firestore for application data
* Firebase Storage for administrator-uploaded product images when required

The exact Firebase architecture and data relationships will be documented separately in:

* `04_DATABASE.md`
* `05_FIREBASE.md`
* `06_SECURITY.md`

---

# 37. Requirements Pending Instructor Instructions

The following payment-related requirements remain intentionally unfinished until additional instructor instructions are provided:

* Exact GCash implementation
* Exact Maya implementation
* Online payment verification
* Payment-provider integration
* Payment-provider refund processing

These requirements should be updated after the instructor provides the necessary information.

The AI must not invent final payment requirements before they are provided.

---

# 38. Requirements Summary

The completed Trend Kicks application must provide:

* Customer registration
* Customer login
* Customer logout
* Customer profile
* Profile editing
* Shoe browsing
* Brand filtering
* Product searching
* Product sorting by rating
* Product details
* Size and color selection
* Stock management
* Persistent shopping cart
* Checkout
* Shipping fee display
* Shipping fee included in total
* Cash on Delivery payment option
* Planned GCash payment option
* Planned Maya payment option
* Order confirmation
* Order history
* Order status tracking
* Order cancellation
* Refund requests
* Predefined refund reasons
* Star ratings
* Product reviews
* In-app notifications
* Administrator product management
* Administrator image management
* Administrator inventory management
* Administrator order management
* Administrator refund management
* Administrator order statistics
* Administrator product-sales statistics
* Firebase data persistence
* Preloaded demonstration products
* Android APK delivery

The application must remain understandable, secure, maintainable, and visually consistent with the documented Trend Kicks design and project rules.
