# Trend Kicks — Project Rules

## 1. Project Overview

Trend Kicks is a Flutter-based shoe e-commerce application designed primarily for Android and delivered as an APK.

The application uses Firebase for authentication, data storage, and other backend functionality required by the documented application features.

The application contains two primary roles:

* Customer
* Administrator

The application is a **single-store/single-brand e-commerce application**.

Trend Kicks is not a multi-vendor marketplace.

This file defines the general rules that the AI must follow when designing, implementing, modifying, and debugging the application.

The detailed functional requirements are documented separately in `01_REQUIREMENTS.md`.

---

# 2. Technology Stack

## Frontend

* Flutter
* Dart

## Backend

* Firebase

The project will use Firebase services where they are required by the documented application features.

The project is expected to use:

* Firebase Core
* Firebase Authentication
* Cloud Firestore
* Firebase Storage when required for uploaded images

Other Firebase services may be introduced later if a documented requirement genuinely needs them.

The AI must not add Firebase services simply because they are available.

---

# 3. Development Philosophy

The application should prioritize:

1. Functionality
2. Security
3. Maintainability
4. Understandability
5. Appropriate simplicity
6. Visual consistency with the provided design

The AI is allowed to make reasonable technical decisions when the documentation does not explicitly specify an implementation detail.

However, the AI must choose the simplest reasonable solution that satisfies the requirements.

The AI must not introduce unnecessary complexity simply because a more advanced architecture or technology exists.

When an important architectural decision could significantly affect the rest of the application, the AI should explain the decision before proceeding.

---

# 4. Documentation Is the Source of Truth

The project documentation defines the intended behavior, requirements, architecture, design, and security expectations of the application.

The AI must read the relevant documentation before implementing a feature.

The AI must not knowingly implement functionality that conflicts with the documentation.

If two documentation files contain conflicting requirements, the AI must identify the conflict instead of silently choosing one.

The project documentation should be treated as higher priority than the AI's assumptions.

The AI must not invent major requirements that were not specified.

Reasonable small implementation decisions are allowed when they do not conflict with the documented requirements.

---

# 5. Documentation Priority

When determining how the project should behave, use the following priority:

1. `00_PROJECT_RULES.md`
2. `01_REQUIREMENTS.md`
3. `02_UI_UX.md`
4. `03_FEATURES.md`
5. `04_DATABASE.md`
6. `05_FIREBASE.md`
7. `06_SECURITY.md`
8. `07_ARCHITECTURE.md`
9. `08_ASSETS.md`
10. `09_DEVELOPMENT_STATUS.md`

If a lower-priority document conflicts with a higher-priority document, the higher-priority document takes precedence until the documentation is updated.

---

# 6. Single-Store Architecture

Trend Kicks is a **single-store/single-brand shoe e-commerce application**.

The application is not a multi-vendor marketplace.

There must be no seller system unless explicitly requested later.

The project does not require:

* Seller registration
* Seller applications
* Seller approval workflows
* Seller accounts
* Seller dashboards
* Seller product management
* Seller-specific stores
* Seller payouts
* Seller commissions
* Multi-vendor management

All products sold through the application are managed by the Trend Kicks administrator.

Nike, Puma, and Adidas represent brands/products carried by Trend Kicks. They are not separate sellers.

The administrator is responsible for managing the store's products, inventory, orders, and related operations.

---

# 7. Figma Design Rules

The provided Figma design is the primary visual reference for the application.

The AI must follow the Figma design's:

* Layout
* Spacing
* Typography
* Colors
* Buttons
* Cards
* Navigation
* Visual hierarchy
* General component style

The AI must not redesign an existing screen simply because it personally prefers another design.

However, the Figma design does not override required functionality documented elsewhere.

If a required feature is missing from the Figma design, the AI must implement the feature using the existing visual language of the application.

For example, if the documentation requires an "Add to Cart" feature but the Figma product card does not contain an Add to Cart button, the AI should add the required functionality while matching the existing Figma style rather than omitting the feature.

If a design detail is not specified in Figma, the AI may make a simple design decision that is visually consistent with the rest of the application.

---

# 8. Platform Target

The primary target platform is Android.

The final school submission will be an Android APK.

The application does not need to be specifically optimized as a desktop or web application unless this requirement is introduced later.

However, the UI must not rely on fixed dimensions that cause the application to break on different Android screen sizes.

Flutter responsive layout practices should be used where appropriate so the application works reasonably across different Android phones and screen sizes.

Cross-platform desktop and web optimization is not a primary project requirement.

---

# 9. Flutter Project Management

The AI must work with the existing Flutter project rather than assuming that it should recreate the entire project from scratch.

Before modifying the project, the AI should inspect:

* Existing Flutter project structure
* `pubspec.yaml`
* Existing Dart files
* Existing assets
* Existing Firebase configuration
* Existing dependencies
* Existing architecture

The AI must not unnecessarily recreate or restructure the Flutter project.

Flutter project initialization and major project-level commands should be performed through the appropriate Flutter tooling.

When a change requires a terminal command, the AI should clearly identify the command and explain its purpose.

The AI must not assume that modifying Dart files alone is sufficient when a change requires a package installation, Firebase configuration, asset configuration, or other project-level setup.

---

# 10. Application Scope

The initial shoe catalog will contain three brands:

* Nike
* Puma
* Adidas

The application should be structured so additional brands can be added by the administrator later without requiring major architectural changes.

Brands are used as the primary product categories/filtering system for the initial version.

The complete functional requirements are defined in `01_REQUIREMENTS.md`.

The AI must not add unrelated e-commerce features without instruction.

---

# 11. Authentication and User Accounts

Authentication is a required foundation of the application.

The application must support:

* User registration
* User login
* User logout
* Authenticated customer sessions
* Administrator authentication

Customer authentication will use email and password through Firebase Authentication.

Customer account information may include:

* Email
* First name
* Last name
* Phone number
* Delivery address
* Optional profile picture

Passwords must never be manually stored as plaintext application data.

The application must distinguish between authenticated customers and administrators.

Authentication and authorization must not rely solely on client-side variables.

The detailed authentication requirements are defined in `01_REQUIREMENTS.md`, `05_FIREBASE.md`, and `06_SECURITY.md`.

---

# 12. Customer Data Protection

Customer-specific information must be associated with the authenticated customer account.

The application must protect private customer data such as:

* Personal information
* Phone number
* Delivery address
* Cart
* Orders
* Notifications
* Refund requests
* Other account-specific information

A customer must not be able to access or modify another customer's private information.

The AI must design customer-specific data access around authenticated user identity rather than relying on values supplied by the client.

---

# 13. Product Features

The application will contain a shoe product catalog.

Products may contain information such as:

* Product ID
* Name
* Brand
* Description
* Price
* Images
* Size variants
* Color variants
* Stock
* Rating
* Review count

The detailed product data structure will be defined in `04_DATABASE.md`.

The AI must not create conflicting product structures in different parts of the application.

---

# 14. Product Variants and Inventory

Products may contain different size and color combinations.

Inventory must be associated with the appropriate product variant where required.

The application must prevent customers from purchasing unavailable inventory.

Inventory changes are sensitive business operations.

Customers must not be allowed to directly manipulate product stock.

Inventory-related authorization and validation must be enforced using appropriate Firebase/backend security mechanisms.

---

# 15. Shopping Cart

The shopping cart is customer-specific.

Cart data must be associated with the authenticated customer.

The cart must persist between application sessions.

If a customer closes the application and later opens it again, their saved cart should remain available.

The AI must avoid maintaining multiple conflicting sources of truth for cart information.

The detailed cart data structure will be defined in `04_DATABASE.md`.

---

# 16. Orders

Orders are customer-specific records.

Orders must preserve the necessary information from the time the order was created.

The price stored in an existing order must not automatically change when an administrator later changes the current product price.

Customers must only be able to access their own orders.

Order status changes are sensitive operations and must be appropriately authorized.

The detailed order structure and lifecycle will be defined in `03_FEATURES.md` and `04_DATABASE.md`.

---

# 17. Notifications

The application will use in-app notifications for relevant events.

Notifications are customer-specific.

The initial notification system may include events such as:

* Order confirmed
* Order preparing
* Order shipped
* Order delivered
* Order cancelled
* Refund approved
* Refund rejected

Phone push notifications are not currently a requirement.

Firebase Cloud Messaging must not be added unless push notifications become a documented requirement later.

---

# 18. Reviews and Ratings

Products may contain customer ratings and reviews.

Authenticated customers may submit ratings and reviews.

The application should maintain an appropriate relationship between:

* Customers
* Products
* Reviews
* Ratings

Product rating information should not be duplicated unnecessarily.

The detailed review behavior and data structure will be defined in `03_FEATURES.md` and `04_DATABASE.md`.

---

# 19. Administrator System

The application must support administrator functionality.

Administrators may:

* Add shoes
* Edit shoes
* Delete shoes
* Manage product information
* Manage product images
* Manage inventory
* View orders
* Update appropriate order statuses
* View the number of orders
* View the number of products sold
* Review refund requests
* Accept or reject refund requests

Administrator permissions must be separate from normal customer permissions.

A customer must not be able to obtain administrator privileges by modifying client-side application data.

Administrator authorization must be enforced through appropriate Firebase/backend security mechanisms.

---

# 20. Product Images

The initial product catalog may use preloaded application assets.

The application should also support administrator-managed product images when required by the documented functionality.

When administrator image uploads are implemented, Firebase Storage should be used where appropriate.

The AI must follow `08_ASSETS.md` when working with preloaded application assets.

The AI must not randomly rename, replace, or delete provided assets without instruction.

---

# 21. Payment

The application is intended to support:

* Cash on Delivery
* Online payment

The planned online payment methods are:

* GCash
* Maya

However, the exact implementation requirements for online payment are currently pending instructor-provided instructions.

The AI must not invent a fake GCash or Maya integration and present it as a real payment system.

Until the payment requirements are provided, payment implementation must remain sufficiently isolated so the final implementation can be changed without requiring a major rewrite of unrelated application functionality.

---

# 22. Refunds

The application is intended to support refund requests.

The refund workflow is:

```text
Customer selects eligible order item
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

The exact payment-provider refund behavior is currently pending instructor-provided payment requirements.

The AI must not invent real payment-provider refund behavior before the required payment architecture is known.

---

# 23. Firebase Security

Security is a core project requirement.

The application must follow the principle:

> Never trust the Flutter client with sensitive authorization or business-critical decisions.

Firebase Security Rules and appropriate backend mechanisms must be used to protect sensitive data.

Customers should only be able to access or modify data they are authorized to access.

Customers must not be able to:

* Read another customer's private data
* Modify another customer's cart
* Modify another customer's orders
* Change their own administrator privileges
* Change product prices
* Modify product inventory
* Change an order to an unauthorized status
* Approve their own refund
* Perform administrator operations

Administrator operations must be protected by appropriate authorization.

Detailed security rules will be documented separately in `06_SECURITY.md`.

---

# 24. Sensitive Information

The AI must never place sensitive credentials or privileged secrets directly inside the Flutter application.

The following must never be exposed through client-side code:

* Firebase Admin credentials
* Service account private keys
* Payment-provider secret keys
* Server-side credentials
* Other privileged secrets

Client-side configuration must not be treated as a replacement for Firebase Security Rules or backend authorization.

---

# 25. Data Validation

Important application data must be validated.

The application should validate user input on the client for usability.

Security-sensitive and business-critical validation must also be enforced by trusted backend/database mechanisms where appropriate.

The AI must not assume that data is safe simply because it came from the Flutter application's UI.

---

# 26. State Management

The project should use a simple and understandable state-management approach.

The initial preferred approach is:

* Normal Flutter state such as `setState()` for local/simple screen state
* Provider for shared application state where appropriate

The AI must not introduce a more complex state-management architecture unless there is a documented reason to do so.

State management should be organized so shared data such as authentication state, cart state, products, and orders does not become duplicated across unrelated screens.

---

# 27. Dependency Rules

The AI should prefer Flutter's built-in functionality and official Firebase packages whenever they are sufficient.

Third-party packages may be added when they provide meaningful functionality that would otherwise require unnecessary complexity.

Before introducing a significant third-party dependency, the AI should explain:

1. What the package does
2. Why it is needed
3. Why existing Flutter/Firebase functionality is insufficient
4. Whether the package introduces meaningful security or maintenance concerns

The project should avoid unnecessary dependencies.

The AI must not add packages simply because they are convenient.

---

# 28. Code Quality

The AI should produce code that is:

* Understandable
* Maintainable
* Modular where appropriate
* Consistent with the established architecture
* Appropriately documented
* Easy for a student developer to understand

The AI should avoid unnecessary abstractions, patterns, or layers that do not provide a clear benefit.

Code should not be made complex merely to appear professional.

---

# 29. Existing Code Protection

When modifying an existing feature, the AI must first inspect the existing implementation.

The AI must:

* Avoid rewriting unrelated functionality
* Avoid deleting working functionality without instruction
* Avoid creating duplicate implementations
* Reuse existing components where appropriate
* Preserve established project conventions
* Modify only the files necessary for the requested task when practical

A small feature request should not result in an unnecessary rewrite of the entire project.

---

# 30. Debugging Rules

When an error occurs, the AI should identify the likely root cause before applying a fix.

The AI must not:

* Hide errors
* Suppress useful error messages simply to make the application appear functional
* Apply unrelated workarounds
* Rewrite large sections of the project without justification

When fixing an issue, the AI should explain:

* What caused the problem
* What was changed
* Why the change fixes it
* What should be tested afterward

---

# 31. AI Development Behavior

Before implementing a significant feature, the AI should:

1. Read the relevant documentation.
2. Inspect the existing project structure.
3. Inspect the existing implementation related to the feature.
4. Determine which existing components can be reused.
5. Identify any documentation conflicts.
6. Identify whether terminal/project configuration changes are required.
7. Implement the smallest appropriate change.
8. Explain important changes.
9. Provide appropriate testing steps.

The AI may make reasonable implementation decisions when the documentation does not specify an exact implementation.

However, it must not silently make major architectural decisions that contradict the documented project requirements.

---

# 32. Terminal and Project Commands

When implementation requires commands such as:

* `flutter pub add`
* `flutter pub get`
* `flutterfire configure`
* Firebase configuration commands
* Build commands
* Testing commands

the AI should clearly provide the command and explain what it does.

The AI should distinguish between:

* Dart code changes
* Flutter project configuration
* Package installation
* Firebase configuration
* Android configuration
* Build/deployment commands

The AI must not assume that a Dart file change automatically performs required project configuration.

---

# 33. Testing

New functionality should be tested after implementation.

Testing should consider:

* Normal user behavior
* Invalid input
* Empty states
* Loading states
* Error states
* Authentication states
* Unauthorized access
* Different Android screen sizes
* Firebase failures
* Stock limitations
* Order state changes
* Cart persistence
* Product variant selection

Security-sensitive functionality should be tested from the perspective of both authorized and unauthorized users.

---

# 34. Project Scope Control

The AI must not add features simply because they are common in e-commerce applications.

Features should only be added when they are:

* Required by the project
* Explicitly requested
* Documented as planned functionality
* Necessary to support another required feature

Potential future improvements should be suggested separately rather than silently implemented.

In particular, the AI must not introduce:

* Seller systems
* Multi-vendor functionality
* Seller registration
* Seller dashboards
* Seller payouts
* Unrequested marketplace features

unless explicitly requested later.

---

# 35. Payment Implementation Status

Online payment implementation is currently **ON HOLD**.

The instructor is expected to provide additional payment-related instructions.

When those instructions become available, update the relevant documentation before implementing the payment system.

Do not make assumptions about the final GCash or Maya integration before the requirements are provided.

---

# 36. Final Principle

The goal is not to create the most complicated e-commerce architecture possible.

The goal is to create a secure, functional, understandable, maintainable, and visually consistent Trend Kicks shoe e-commerce application that satisfies the documented school requirements.

When multiple technically valid solutions exist, prefer the solution that:

1. Meets the requirements
2. Maintains security
3. Fits the existing architecture
4. Is understandable
5. Avoids unnecessary complexity
6. Can be maintained and demonstrated by the student developer
