# Trend Kicks — Security Specification

## 1. Purpose

This document defines the security requirements for the Trend Kicks Flutter e-commerce application.

The security design must protect:

- Customer accounts
- Customer profile information
- Products
- Product prices
- Product stock
- Carts
- Orders
- Payments
- Reviews
- Refund requests
- Notifications
- Firebase Storage
- Administrative functions

Security must be enforced through Firebase Authentication, Firestore Security Rules, Firebase Storage Security Rules, and appropriate application/backend validation.

The Flutter client must never be treated as a trusted security boundary.

---

## 2. Authentication

Firebase Authentication is responsible for user authentication.

Users must be authenticated before performing protected customer actions.

Authentication is required before a customer can:

- Add items to a persistent cart
- Checkout
- Place an order
- View their orders
- Submit a review
- Request a refund
- Access protected account information

A user may enter and browse the application without logging in.

---

## 3. Public Product Browsing

Unauthenticated users may:

- Open the application
- Browse products
- View product details
- Search products
- Filter products
- View publicly available product information

Login is required when the user attempts to perform purchasing-related or account-protected actions.

---

## 4. Firebase Authentication Passwords

Passwords must be handled by Firebase Authentication.

The application must not store plaintext passwords in:

- Cloud Firestore
- Firebase Storage
- Local application databases
- Product documents
- User profile documents

The `UserModel` must not contain a password field.

Firebase Authentication is responsible for:

- Password storage
- Password verification
- Login authentication
- Registration authentication
- Authentication state

---

## 5. User Data Protection

Each authenticated user must only be able to access their own protected user data.

A customer must not be able to:

- Read another customer's private profile
- Modify another customer's profile
- Delete another customer's profile
- Access another customer's private account information

The user's Firebase Authentication identity should be used to verify ownership.

---

## 6. User Profile Editing

Customers may edit only their own allowed profile information.

The editable fields are:

- Full name
- Phone number
- Address
- Profile photo

Customers must not be able to modify protected account fields such as:

- User ID
- Role
- Administrative permissions
- Other users' information

---

## 7. Profile Edit Cooldown

Profile information changes should have a configurable cooldown period.

After a customer changes their allowed profile information, the application should prevent them from repeatedly changing the information immediately.

The cooldown should apply to:

- Full name
- Phone number
- Address
- Profile photo

The cooldown should not allow customers to bypass protection by directly modifying Firestore data.

The exact cooldown duration should be configurable rather than hardcoded into multiple parts of the application.

The security rules and backend validation should support the cooldown requirement where technically appropriate.

---

## 8. User Roles

The application uses one primary user model.

Possible roles include:

- `customer`
- `admin`

Newly registered users must automatically become:

- `customer`

Customers must not be able to change their own role.

A customer must never be able to submit a client-side request such as:

`role = admin`

and gain administrator privileges.

---

## 9. Admin Account Creation

Admin accounts must be created or promoted manually.

Normal public registration must never allow a customer to select:

- `admin`

as their role.

The application must not expose a public "Register as Admin" option.

Administrator privileges must be granted through a controlled process.

---

## 10. Admin Access

Authenticated administrators may access authorized administrative information and functions.

Administrators may manage:

- Products
- Product variants
- Product prices
- Product stock
- Product availability
- Orders
- Refund requests
- Reviews
- Users where required for administration
- Store-related notifications

Administrative access must be verified through trusted authorization information.

---

## 11. Customer and Admin Separation

Customers and administrators must have different permissions.

Customers may:

- Browse products
- Manage their own profile
- Manage their own cart
- Place orders
- View their own orders
- Submit eligible reviews
- Edit their own reviews
- Submit refund requests for their own eligible order items
- View their own notifications

Administrators may perform authorized management operations.

Customers must never receive administrative permissions simply because an administrative screen exists in the Flutter application.

---

## 12. Product Read Access

Public product browsing may be allowed without authentication.

Unauthenticated users may read appropriate public product information.

Product information intended for public display may include:

- Brand
- Model
- Edition
- Description
- Category
- Image
- Price
- Availability
- Rating
- Review count
- Available variants where appropriate

Sensitive administrative information must not be exposed unnecessarily.

---

## 13. Product Write Access

Only authorized administrators may:

- Create products
- Edit products
- Delete products
- Change product prices
- Change product availability
- Add variants
- Modify variants
- Change variant stock

Customers must not be allowed to directly modify product documents.

---

## 14. Product Price Protection

Customers must never be able to modify product prices through client-side requests.

A customer must not be able to manipulate:

- Product price
- Adult price
- Kids price
- Historical order price

The server-side/database rules must prevent unauthorized price changes.

---

## 15. Product Stock Protection

Customers must not be able to directly modify product stock.

Stock changes must be performed through authorized application logic and administrative operations.

The system must protect against:

- Negative stock
- Unauthorized stock increases
- Unauthorized stock decreases
- Overselling
- Client-side stock manipulation

---

## 16. Stock Validation

The application must validate stock before an order is completed.

The client application must not be trusted to report its own available stock.

Example:

If a product variant has:

- Stock = 5

a customer must not be able to create an order for:

- Quantity = 6

The backend/database logic must prevent the invalid transaction.

---

## 17. Cart Privacy

Each customer's cart must be private.

Customer A must not be able to:

- Read Customer B's cart
- Modify Customer B's cart
- Delete Customer B's cart

A customer may only access the cart associated with their authenticated user ID.

---

## 18. Cart Data Protection

Customers may modify their own cart through authorized application operations.

However, the client must not be trusted to bypass:

- Stock limits
- Product availability
- Product pricing rules
- Quantity restrictions

The final checkout process must revalidate important information.

---

## 19. Order Privacy

Customers may only read their own orders.

Customer A must not be able to:

- Read Customer B's orders
- Modify Customer B's orders
- Cancel Customer B's orders
- Access Customer B's private shipping information
- Access Customer B's payment information

Administrators with appropriate permissions may access orders for store management.

---

## 20. Order Creation

Customers may create orders only for themselves.

An order must be associated with the authenticated customer's user ID.

The application must not trust a client-provided user ID if it does not match the authenticated identity.

The server/database security design must enforce ownership.

---

## 21. Order Price Protection

Customers must not be able to directly set or modify:

- Order subtotal
- Order total
- Product price used for the order
- Shipping fee where the value is controlled by the application
- Payment status

The final order values must be calculated or validated by trusted application/backend logic.

---

## 22. Historical Order Protection

Once an order has been created, customers must not be able to modify historical transaction information such as:

- Historical product price
- Quantity
- Order total
- Payment status
- Other protected transaction information

Historical order data must remain accurate.

---

## 23. Order Status Protection

Customers must not be able to directly change their order status.

For example, a customer must not be able to change:

- Pending

to:

- Delivered
- Shipped

Order status transitions must be controlled by authorized application logic and administrative permissions.

---

## 24. Order Cancellation

Customers may cancel an order only when the application's cancellation rules permit it.

Once an order reaches:

- Shipped

the customer must not be able to cancel it.

The restriction must not rely solely on hiding the cancellation button in Flutter.

The backend/database security design must also protect the rule.

---

## 25. Payment Security

Customers must not be able to manually change their payment status to:

- Paid

Payment status must be controlled by trusted payment-processing logic.

Supported payment methods are:

- Cash on Delivery
- GCash
- Maya

Payment implementation must verify successful payment before marking an online payment as successfully paid.

---

## 26. Review Security

Customers may submit reviews only when they satisfy the application's review eligibility rules.

A customer may:

- Create their own eligible review
- Edit their own review

A customer may not:

- Edit another user's review
- Delete another user's review
- Change another user's rating
- Create unauthorized reviews on behalf of another user

---

## 27. Review Eligibility

A review should be associated with:

- User ID
- Product ID
- Order ID

The system should verify that the customer purchased the relevant product and that the order reached the required delivered/received state before allowing the review.

The Flutter UI alone must not be the only enforcement mechanism.

---

## 28. Review Rating Protection

Review ratings must be limited to:

- 1
- 2
- 3
- 4
- 5

Customers must not be able to submit invalid ratings such as:

- 0
- 6
- -1
- 100

The data validation and backend/security design should enforce the allowed range.

---

## 29. Refund Request Security

Customers may create refund requests only for:

- Their own orders
- Eligible order items

Customers must not be able to create refund requests against another customer's order.

Each refund request should be connected to:

- User ID
- Order ID
- Order item ID
- Product ID

---

## 30. Refund Status Protection

Customers may submit refund requests and view their own requests.

Customers must not be able to change:

- Pending

to:

- Approved
- Rejected

Only authorized administrators may review and change refund status.

---

## 31. Refund Review Security

Only authorized administrators may:

- Review refund requests
- Approve refunds
- Reject refunds
- Add administrative review information
- Change refund status

The administrator who reviewed the request should be recorded where appropriate.

---

## 32. Refund Privacy

Customers may only view their own refund requests.

A customer must not be able to:

- View another customer's refund request
- Modify another customer's refund request
- Approve their own refund
- Reject their own refund
- Modify an administrator's decision

---

## 33. Notification Security

Customers may only access their own notifications.

Customer A must not be able to read Customer B's notifications.

A customer may update the read state of their own notifications where permitted.

Administrative notification functionality must remain protected.

---

## 34. Firebase Storage Security

Firebase Storage must use access controls appropriate to each file type.

Customer profile images should only be writable by the corresponding authenticated user, subject to the application's validation rules.

Customers must not be able to:

- Replace product images
- Upload files into administrative product storage locations
- Delete another customer's profile image
- Access private files belonging to another customer

Administrators may manage authorized product images.

---

## 35. File Upload Validation

Uploaded files should be validated where possible.

Validation should consider:

- File type
- File size
- Ownership
- Destination path

The application should not blindly accept arbitrary files from untrusted users.

---

## 36. Firebase Security Rules

Firebase Security Rules are a core part of the application's security model.

Security rules must protect:

- Firestore
- Firebase Storage

Rules must verify:

- Authentication state
- User ownership
- User role
- Allowed operations
- Protected fields where applicable

---

## 37. Client Application Is Not Trusted

The Flutter application must be treated as an untrusted client.

Hiding buttons, screens, routes, or admin functionality in Flutter is not sufficient security.

For example:

Removing the "Delete Product" button from the customer UI does not prevent a malicious client from attempting a direct database request.

Firebase Security Rules and trusted backend logic must enforce the actual permission.

---

## 38. Firebase Configuration Is Not the Security Boundary

Firebase configuration information included in the Flutter application should not be treated as a secret password.

The application's security must not depend on hiding Firebase configuration values.

Actual data protection must come from:

- Firebase Authentication
- Firestore Security Rules
- Firebase Storage Security Rules
- Trusted backend/application logic
- Proper authorization checks

---

## 39. Role Protection

The `role` field is security-sensitive.

Customers must not be able to update their own role.

A request attempting to change:

- `role = customer`

to:

- `role = admin`

must be denied.

Administrative role assignment must happen through a controlled process.

---

## 40. User Data Ownership

Ownership should be based on the authenticated Firebase user identity.

Conceptually:

- Authenticated user UID
- Matches document owner userId
- Access allowed

If the IDs do not match:

- Access denied

This ownership model should be used for:

- Profiles
- Carts
- Orders
- Reviews
- Refund requests
- Notifications

---

## 41. Protected Fields

Customers must not directly modify protected fields such as:

- User ID
- Role
- Order total
- Historical order price
- Payment status
- Refund status
- Product stock
- Product price
- Administrative review information
- Other users' information

The security rules should restrict unauthorized field modifications where appropriate.

---

## 42. Data Validation

Important data should be validated before being written.

Examples include:

- Quantity must be greater than zero.
- Stock must not be negative.
- Price must not be negative.
- Rating must be between 1 and 5.
- Required IDs must exist.
- Required relationships must be valid.
- User ownership must be verified.
- Protected fields must not be client-controlled.

---

## 43. Authentication State

The application should properly respond to Firebase Authentication state.

When a user logs in:

- Their authenticated identity becomes available.
- Protected customer features become accessible.

When a user logs out:

- Protected account information must no longer be accessible through the customer session.
- The application should return to the appropriate unauthenticated state.

---

## 44. Unauthorized Access

If a user attempts to access protected data without authorization, the application should:

- Deny the request.
- Avoid exposing sensitive information.
- Display an appropriate user-facing message where necessary.

Security errors should not expose internal secrets or unnecessary implementation details.

---

## 45. Account Deletion and Historical Data

If a customer account is deleted, historical transaction information should be preserved where required.

The initial approach is:

- Preserve historical orders and transaction records.
- Preserve necessary review/transaction records.
- Remove or anonymize personal information where appropriate.

The system should avoid destroying historical transaction records solely because the customer account was removed.

The exact anonymization process should follow the final implementation requirements.

---

## 46. Admin Visibility

Authorized administrators may access information required for store operations, including:

- Customer accounts where necessary
- Orders
- Products
- Product inventory
- Reviews
- Refund requests
- Store notifications

Administrative access must not automatically grant unnecessary permissions outside the administrator's intended functions.

---

## 47. Customer Privacy

Customers must not be able to see other customers':

- Orders
- Cart contents
- Addresses
- Phone numbers
- Private profile information
- Refund requests
- Private notifications
- Other private account information

Only the appropriate customer and authorized administrators should have access.

---

## 48. Security Against Price Manipulation

The application must prevent customers from manipulating prices through modified client requests.

For example, if a product costs:

- ₱5,000

the customer must not be able to send:

- ₱1

as the purchase price and have the database accept it.

The trusted application/backend process must determine or validate the actual price.

---

## 49. Security Against Stock Manipulation

The application must prevent customers from manipulating stock.

A customer must not be able to:

- Increase stock
- Reduce another customer's reserved stock
- Purchase more than available stock
- Set stock to an arbitrary value

Stock changes must be controlled by authorized operations.

---

## 50. Security Against Order Manipulation

Customers must not be able to manipulate:

- Order owner
- Product price
- Quantity beyond available stock
- Order total
- Payment status
- Order status
- Refund status

The database/security layer must protect these fields.

---

## 51. Security Against Role Manipulation

Customers must not be able to elevate their own privileges.

The application must not trust:

- Client-provided role values
- Client-side admin flags
- Hidden Flutter routes
- Local storage values

Administrative authorization must be validated through trusted Firebase authentication/authorization mechanisms.

---

## 52. Security Against Unauthorized File Access

Storage paths should be organized so that access can be controlled.

Examples may include separate logical areas for:

- User profile images
- Product images

Access rules should ensure that customers can only write to locations they are authorized to use.

---

## 53. Security and UI

The UI should reflect the user's permissions.

For example:

Customers should not see:

- Admin dashboard
- Product management
- Stock management
- Refund approval controls
- User administration controls

However, hiding these UI elements is only a usability feature.

The actual authorization must still be enforced by Firebase security controls.

---

## 54. Security and Architecture

Security responsibilities should be distributed according to `05_ARCHITECTURE.md`.

The architecture should separate:

- UI
- Data models
- Services
- Providers/state management
- Firebase access
- Security rules

The AI must not place all security logic directly inside UI widgets.

---

## 55. Security and Data Models

The security implementation must remain consistent with `06_DATA_MODELS.md`.

The security rules should account for the relationships between:

- Users
- Products
- Product variants
- Carts
- Orders
- Order items
- Reviews
- Refund requests
- Notifications

---

## 56. Security Testing

Before considering the application complete, test at minimum:

- Unauthenticated user attempting protected actions
- Customer accessing another customer's profile
- Customer accessing another customer's cart
- Customer accessing another customer's order
- Customer accessing another customer's refund
- Customer modifying product price
- Customer modifying stock
- Customer changing their role to admin
- Customer changing another user's information
- Customer approving their own refund
- Customer modifying an order total
- Customer changing an order to delivered
- Customer cancelling an already shipped order
- Unauthorized product image upload
- Invalid review rating
- Overselling a product variant

All unauthorized operations should be denied.

---

## 57. Security Principle

The main security principle for Trend Kicks is:

> Never trust the client.

Flutter controls the user interface.

Firebase Authentication identifies the user.

Firestore and Storage Security Rules enforce access permissions.

Trusted application/backend logic validates important business operations.

---

## 58. Final Security Requirements

The implementation must ensure:

- Users must authenticate before protected purchasing/account actions.
- Public users may browse products.
- Customer data is private.
- Carts are private.
- Orders are private to the customer unless accessed by authorized administrators.
- Reviews belong to their creators.
- Refund requests belong to their creators and associated orders.
- Only administrators can manage products.
- Only administrators can manage inventory.
- Only administrators can approve or reject refunds.
- Customers cannot manipulate prices.
- Customers cannot manipulate stock.
- Customers cannot manipulate order totals.
- Customers cannot manipulate payment status.
- Customers cannot manipulate order status.
- Customers cannot promote themselves to admin.
- Admin accounts are created manually.
- Passwords are handled by Firebase Authentication.
- Passwords are not stored in Firestore.
- Firebase configuration is not treated as the security boundary.
- Firestore Security Rules protect database access.
- Firebase Storage Security Rules protect file access.
- Profile editing is restricted to approved fields and subject to the configured cooldown.
- Historical transaction information is preserved.
- Deleted accounts do not automatically destroy required historical transaction records.
- The Flutter UI must reflect permissions but must never be the only security mechanism.

The AI must follow this document together with:

- `00_RULES.md`
- `01_FEATURES.md`
- `02_UI_UX.md`
- `03_FIREBASE.md`
- `05_ARCHITECTURE.md`
- `06_DATA_MODELS.md`

The AI must inspect the existing project before implementing security-related code and must not blindly overwrite existing files.