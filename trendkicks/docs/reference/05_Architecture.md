# Trend Kicks — Flutter Architecture Specification

## 1. Purpose

This document defines the architecture and code organization for the Trend Kicks Flutter e-commerce application.

The application is a mobile-first shoe e-commerce application for the Trend Kicks self-owned shoe brand.

The architecture must remain:

- Understandable
- Maintainable
- Organized
- Secure
- Appropriate for a school project
- Easy to extend
- Compatible with Firebase
- Compatible with the UI/UX requirements
- Simple enough for the developer to understand

The AI must follow this architecture when creating or modifying Flutter code.

The AI must read the other project documentation before making architectural decisions.

Relevant documentation:

- `00_RULES.md`
- `01_FEATURES.md`
- `02_UI_UX.md`
- `03_FIREBASE.md`
- `05_ARCHITECTURE.md`

If another project document defines a specific requirement, the AI must follow that requirement.

---

## 2. Architecture Style

Trend Kicks will use a feature-based, layered Flutter architecture.

The architecture should provide separation between:

- UI
- State management
- Models
- Business logic
- Firebase/data access
- Shared application utilities

The project should avoid unnecessarily complicated architecture.

The goal is to keep the project understandable while still maintaining good separation of responsibilities.

---

## 3. High-Level Architecture

The application should generally follow this flow:

UI
↓
State Management
↓
Services / Business Logic
↓
Firebase

For example:

Product Screen
↓
Product Provider
↓
Product Service
↓
Cloud Firestore

Another example:

Login Screen
↓
Auth Provider
↓
Auth Service
↓
Firebase Authentication

The UI should not contain large amounts of Firebase logic.

---

## 4. Flutter Project Root

The Flutter project will be created manually by the developer.

The AI must not assume that it is responsible for creating the entire Flutter project.

The developer will create the Flutter project using the Flutter CLI.

Example command:

`flutter create trend_kicks`

The AI may provide terminal commands when required, but the developer will execute those commands.

---

## 5. Recommended lib Structure

The main application code should follow a structure similar to:

- `lib/`
  - `core/`
    - `constants/`
    - `theme/`
    - `routing/`
    - `utils/`
    - `widgets/`
  - `models/`
  - `services/`
    - `auth/`
    - `firestore/`
    - `storage/`
    - `notifications/`
  - `providers/`
  - `features/`
    - `auth/`
    - `home/`
    - `products/`
    - `cart/`
    - `checkout/`
    - `orders/`
    - `reviews/`
    - `refunds/`
    - `profile/`
    - `admin/`
  - `main.dart`

The exact number of files may change as development progresses.

The AI must not create unnecessary folders merely to make the architecture appear more complex.

---

## 6. Core Folder

The `core/` folder contains reusable application-wide functionality.

Examples include:

- `constants/`
- `theme/`
- `routing/`
- `utils/`
- `widgets/`

Core code should not contain logic that belongs specifically to one feature.

---

## 7. Constants

The `core/constants/` folder should contain reusable constants.

Examples include:

- Application name
- Firebase collection names
- Order status values
- Refund status values
- Payment method values
- Brand values
- Shared limits
- Application configuration values

Do not duplicate the same constant throughout multiple Dart files.

For example, instead of repeatedly writing `"Pending"` throughout the application, create an appropriate shared constant or enum when useful.

---

## 8. Theme

The `core/theme/` folder should contain application-wide visual configuration.

This may include:

- ThemeData
- Text styles
- Color definitions
- Button styles
- Input styles
- Card styles
- App-wide visual constants

The theme should follow the provided Figma design.

The AI must not randomly introduce a new visual style that conflicts with `02_UI_UX.md`.

---

## 9. Routing

The `core/routing/` folder should contain navigation-related configuration.

The routing system should make it possible to navigate between areas such as:

- Authentication
- Home
- Products
- Product Details
- Cart
- Checkout
- Order Confirmation
- Orders
- Order Details
- Reviews
- Refunds
- Profile
- Admin

Protected routes should be appropriately restricted.

---

## 10. Shared Widgets

The `core/widgets/` folder should contain reusable widgets that are used across multiple features.

Examples:

- Loading indicator
- Error display
- Reusable buttons
- Reusable cards
- Empty-state widgets
- Shared dialogs
- Shared app bars
- Shared form components

Do not place feature-specific widgets here.

If a widget is only used by the product feature, it should normally remain inside the product feature.

---

## 11. Models

The `models/` folder contains Dart data models.

Initial models should include concepts such as:

- `UserModel`
- `ProductModel`
- `ProductVariantModel`
- `CartModel`
- `CartItemModel`
- `OrderModel`
- `OrderItemModel`
- `ReviewModel`
- `RefundRequestModel`
- `NotificationModel`

Additional models may be created when required.

Models should represent application data rather than containing UI code.

---

## 12. Model Responsibilities

Models should be responsible for representing data.

A model may contain:

- Fields
- Constructors
- Serialization
- Deserialization
- `fromMap`
- `toMap`
- `fromJson`
- `toJson`

where appropriate.

Models should not contain large amounts of UI code.

Models should not directly manage navigation.

Models should not directly control widgets.

---

## 13. Product Model

The product model should support the requirements defined in `01_FEATURES.md` and `03_FIREBASE.md`.

Product information may include:

- Product ID
- Name
- Brand
- Description
- Price
- Images
- Rating
- Review count
- Variants
- Availability
- Creation timestamp
- Update timestamp

The exact Dart field names should remain consistent throughout the project.

---

## 14. Product Variant Model

Product variants must support inventory based on:

- Size
- Color
- Stock

A variant should have a unique identifier.

Conceptually:

- Product
  - Red / Size 8 / Stock 3
  - Red / Size 9 / Stock 5
  - Black / Size 8 / Stock 2
  - Black / Size 9 / Stock 0

The architecture must allow different quantities for different size/color combinations.

---

## 15. Cart Models

Cart functionality should use appropriate models.

A cart item should preserve enough information to identify:

- Product
- Variant
- Size
- Color
- Quantity
- Price
- Image

The cart belongs to the authenticated user.

---

## 16. Order Models

Orders should contain models for:

- Order
- Order item

An order should preserve the purchase information required by the project.

This includes:

- Product
- Variant
- Quantity
- Price at purchase
- Shipping address
- Shipping fee
- Total
- Payment method
- Order date
- Status

Historical order information must not depend on the current product data.

---

## 17. Feature-Based Structure

Feature-specific code should be organized under the `features/` folder.

Each major application feature should have its own area.

Example:

- `features/`
  - `auth/`
  - `home/`
  - `products/`
  - `cart/`
  - `checkout/`
  - `orders/`
  - `reviews/`
  - `refunds/`
  - `profile/`
  - `admin/`

The exact internal structure of each feature may vary depending on complexity.

---

## 18. Authentication Feature

The `features/auth/` folder handles authentication-related UI and logic.

Possible screens include:

- Login
- Register

Authentication functionality includes:

- Registration
- Login
- Logout
- Authentication state
- Form validation
- Authentication error handling

Firebase Authentication logic should be handled through the appropriate service rather than directly inside the UI.

---

## 19. Home Feature

The `features/home/` folder contains the customer home screen.

It may contain:

- Featured products
- Brand browsing
- Search entry
- Recommended products
- Navigation to shopping areas

The exact UI must follow `02_UI_UX.md`.

---

## 20. Product Feature

The `features/products/` folder handles product browsing and product details.

It may include:

- Product listing
- Product cards
- Product detail page
- Product search
- Product filtering
- Sorting
- Brand filtering
- Rating sorting
- Size selection
- Color selection
- Stock information

Product UI must follow the provided Figma design.

---

## 21. Search Architecture

Search should support the behavior defined in `01_FEATURES.md`.

For example, searching `Jordan` should allow the user to discover products whose names contain or reasonably match:

- Jordan 1
- Jordan 2
- Jordan 3
- Jordan 11

The implementation should remain simple and appropriate for the project.

Do not introduce a third-party search engine unless explicitly approved.

---

## 22. Cart Feature

The `features/cart/` folder handles:

- Viewing cart
- Adding products
- Removing products
- Updating quantities
- Validating stock
- Calculating cart subtotal
- Proceeding to checkout

Cart persistence should use the architecture defined in `03_FIREBASE.md`.

---

## 23. Checkout Feature

The `features/checkout/` folder handles:

- Shipping information
- Order summary
- Shipping fee
- Payment method selection
- Order submission
- Order validation

Supported payment methods currently include:

- Cash on Delivery
- GCash
- Maya

The exact online payment integration remains subject to the instructor's final requirements.

Do not implement an unapproved payment gateway as if it were a real production payment system.

---

## 24. Order Feature

The `features/orders/` folder handles:

- Order history
- Order details
- Order status
- Order cancellation
- Delivery information
- Refund requests
- Review eligibility

Customers should only see their own orders.

---

## 25. Order Status Architecture

Order status should use a consistent representation.

Initial statuses:

- Pending
- Confirmed
- Preparing
- Shipped
- Delivered
- Cancelled

The UI should respond to the current order status.

Business rules should prevent invalid transitions.

For example, once an order is `Shipped`, the customer must not be able to change it to `Cancelled`.

---

## 26. Review Feature

The `features/reviews/` folder handles:

- Creating reviews
- Editing reviews
- Displaying reviews
- Star ratings
- Review validation

Customers can review eligible products after the relevant order has been delivered.

The architecture must prevent users from reviewing products they did not successfully purchase and receive.

---

## 27. Refund Feature

The `features/refunds/` folder handles:

- Refund request creation
- Refund reason selection
- Refund request status
- Refund history
- Admin refund review

Refund requests are item-specific.

A customer may request a refund for one item within a multi-item order without automatically refunding the entire order.

The refund flow should be:

- Customer selects a specific item.
- Customer selects a preloaded refund reason.
- Customer submits the refund request.
- The request is sent to the admin.
- An authorized admin reviews the request.
- Admin accepts or rejects the request.
- The customer can view the refund request status.

Only authorized admin accounts can review refund requests.

---

## 28. Admin Feature

The `features/admin/` folder contains administrator functionality.

The Trend Kicks application is a self-owned store.

There is no seller marketplace system.

Do not create:

- Seller registration
- Seller applications
- Seller dashboards
- Seller approval
- Multiple seller accounts

The administrator acts as the store manager.

---

## 29. Admin Product Management

The admin feature must support:

- Add product
- Edit product
- Delete product
- Add product images
- Manage variants
- Manage sizes
- Manage colors
- Manage stock
- Manage availability

Admin actions must be protected by Firebase authorization.

---

## 30. Admin Order Management

Administrators should be able to:

- View orders
- View order details
- View required customer shipping information
- Update order status

Customers must never have access to the admin order-management functionality.

---

## 31. Admin Refund Management

Administrators should be able to:

- View refund requests
- Review refund requests
- Approve refunds
- Reject refunds

Only authorized administrators can perform these actions.

---

## 32. Providers / State Management

The application will use Provider for state management unless a later project requirement explicitly changes this decision.

Providers should handle application state such as:

- Authentication state
- Products
- Cart
- Orders
- Notifications
- Profile
- Admin operations

Providers should not become giant classes containing the entire application.

Create separate providers based on feature responsibility.

---

## 33. Provider Responsibility

A provider should generally:

- Hold relevant state
- Expose state to the UI
- Call appropriate services
- Handle loading state
- Handle error state
- Notify listeners when appropriate

Providers should not contain large widget trees.

Providers should not directly build UI.

---

## 34. Services

The `services/` folder contains communication with external/backend systems.

Examples:

- `services/auth/`
- `services/firestore/`
- `services/storage/`
- `services/notifications/`

Services should isolate Firebase-specific operations from the UI.

---

## 35. Authentication Service

The authentication service should contain operations such as:

- Register
- Login
- Logout
- Current user
- Authentication state

The service should use Firebase Authentication.

UI widgets should not contain repeated Firebase Authentication calls.

---

## 36. Firestore Services

Firestore services should contain database operations.

Examples:

- `ProductService`
- `CartService`
- `OrderService`
- `ReviewService`
- `RefundService`
- `NotificationService`
- `UserService`

The exact number of services may be adjusted when appropriate.

Do not create services that contain only one unnecessary line of code.

---

## 37. Storage Service

A storage service should handle Firebase Storage operations such as:

- Uploading product images
- Deleting product images
- Uploading profile images

The service should return the required download URL/reference for Firestore.

---

## 38. Notification Service

The notification service should handle notification-related Firebase functionality.

This may include:

- Reading notification records
- Marking notifications as read
- Registering notification functionality
- Firebase Cloud Messaging integration where implemented

The application should not use SMS as its notification mechanism.

---

## 39. Firebase Separation

Firebase-specific code should remain separated from UI code.

Avoid patterns such as:

`Widget → FirebaseFirestore.instance.collection(...)`

being repeated throughout many screens.

Prefer:

`Widget → Provider → Service → Firebase`

This keeps the application easier to maintain.

---

## 40. UI and Business Logic Separation

Widgets should primarily handle:

- Layout
- User interaction
- Displaying state
- Calling appropriate provider methods

Widgets should avoid containing large business rules.

For example, stock validation should not exist only as a button condition inside a widget.

The underlying service/business logic must also enforce important rules.

---

## 41. Security Separation

Security must not depend on Flutter UI.

The architecture must assume that a malicious client can modify the application.

Important rules must also be enforced through Firebase:

- User ownership
- Admin authorization
- Stock restrictions
- Order ownership
- Refund permissions
- Review eligibility
- Price integrity

See `03_FIREBASE.md`.

---

## 42. Navigation Guards

Protected areas should require authentication.

Examples:

- Cart
- Checkout
- Orders
- Profile
- Refunds
- Admin

The exact public/private behavior should follow `01_FEATURES.md`.

Admin routes must additionally verify administrator authorization.

---

## 43. Authentication Flow

The general authentication flow is:

Application starts
↓
Check Firebase authentication state
↓
Not logged in?
↓
Login / Register
↓
Authenticated
↓
Load user profile
↓
Determine role
↓
Customer or Admin
↓
Open appropriate application area

The UI should not assume the user is logged in before Firebase authentication state is known.

---

## 44. Registration Flow

The registration flow should generally be:

Register Form
↓
Validate input
↓
Firebase Authentication
↓
Create user document
↓
Assign customer role
↓
Automatically logged in

Users must not choose the admin role during registration.

---

## 45. Logout Flow

Logout should:

- Sign out from Firebase Authentication
- Clear appropriate local application state
- Return the user to the authentication flow

After logout, protected screens must no longer be accessible through normal application navigation.

---

## 46. Responsive Design

The application is primarily intended to be distributed as an Android APK.

Therefore:

- Mobile is the primary target.
- The UI should be responsive to different mobile screen sizes.
- Layouts should avoid unnecessary fixed dimensions.
- The application should not depend on one specific phone resolution.
- Tablet and larger screens may be supported where practical.

The project does not need a completely separate desktop design unless required later.

---

## 47. Responsive UI Rules

Avoid excessive hard-coded values such as:

`width: 390`

when the value represents the entire screen width.

Prefer responsive Flutter techniques such as:

- MediaQuery
- LayoutBuilder
- Flexible
- Expanded
- FractionallySizedBox
- SafeArea
- Wrap
- SingleChildScrollView

Use fixed dimensions when they are appropriate for individual components.

---

## 48. Figma Integration

The UI must follow the Figma references provided in the `design/` folder.

The AI must:

- Inspect the design references.
- Identify the intended layout.
- Follow the visual hierarchy.
- Follow the color palette.
- Follow typography.
- Follow spacing.
- Follow component styling.
- Follow navigation patterns shown in the design.

If a required feature exists in `01_FEATURES.md` but does not appear in Figma, the AI should integrate the feature while preserving the existing visual style.

The Figma design is the visual reference.

The feature documentation is the functional reference.

---

## 49. Design Folder

The project contains:

`design/`

The AI should look inside this folder when working on UI implementation.

The images inside the folder correspond to the application screens/components.

The AI should use the filenames and visual content to understand which screen each reference represents.

The AI must not ignore the design folder when implementing UI.

---

## 50. Required Features vs Design

If there is a conflict between:

- A required feature
- A missing element in the Figma design

the AI should not remove the required feature.

Instead, integrate the feature naturally using the existing Figma visual language.

Example:

If Figma does not show an Add to Cart button but the requirements require Add to Cart:

- Do not remove Add to Cart.
- Add it using the same visual style as the Figma design.

---

## 51. Existing Project Structure

Before creating new files, the AI must inspect the existing Flutter project.

The AI should not assume the project is empty.

Before changing architecture, the AI should:

- Inspect the existing folders.
- Inspect `pubspec.yaml`.
- Inspect `main.dart`.
- Inspect existing Firebase configuration.
- Inspect existing providers/services/models.
- Reuse existing structures where appropriate.

---

## 52. Avoid Duplicate Implementations

The AI must not create duplicate functionality if an appropriate implementation already exists.

Before creating a new:

- Provider
- Service
- Model
- Utility
- Widget
- Screen

the AI should check whether one already exists.

If an existing implementation can reasonably be reused, extend it instead of creating a duplicate.

---

## 53. File Naming

Use consistent Dart naming conventions.

Examples:

- `product_model.dart`
- `product_service.dart`
- `product_provider.dart`
- `product_detail_screen.dart`
- `product_card.dart`

Use:

- `snake_case` for filenames.
- `PascalCase` for classes.
- `camelCase` for variables and methods.

---

## 54. One Responsibility Per File

Files should have a clear purpose.

Avoid creating extremely large files containing:

- Multiple unrelated screens
- All Firebase operations
- All providers
- All models
- All business logic

If a file becomes excessively large, consider separating it according to feature responsibility.

Do not split files unnecessarily just for the sake of having more files.

---

## 55. Reusable Components

When multiple screens use the same component, consider creating a reusable widget.

Examples:

- Product card
- Rating display
- Quantity selector
- Loading indicator
- Empty state
- Status badge
- Primary button

Reusable widgets should be placed in the appropriate feature or `core/widgets/` depending on whether they are feature-specific or application-wide.

---

## 56. Error Handling

The architecture should provide consistent handling for:

- Network failures
- Firebase errors
- Authentication errors
- Invalid form input
- Missing data
- Permission errors
- Out-of-stock products
- Order submission failures
- Image upload failures

Errors should be converted into understandable messages for users.

Do not expose raw Firebase error messages unnecessarily.

---

## 57. Loading States

Firebase operations should provide appropriate loading states.

Examples:

- Login
- Registration
- Product loading
- Cart updates
- Checkout
- Order submission
- Image upload
- Refund submission
- Admin operations

The UI should not appear frozen while waiting for Firebase operations.

---

## 58. Empty States

The architecture should support clear empty states.

Examples:

- No products found.
- Your cart is empty.
- You have no orders yet.
- You have no notifications.
- No refund requests found.

Empty states should follow the Figma visual style.

---

## 59. Product Data and Demo Data

The application will contain preloaded/demo products for demonstration purposes.

The architecture must allow the application to display these products without requiring an administrator to manually create every product before the APK can be demonstrated.

Admin-created products must use the same product model and data structure as demo products.

---

## 60. Product Images

Some product images will be included as project assets.

Admin-uploaded images will use Firebase Storage.

The architecture should allow both:

- Local/preloaded demo image
- Firebase Storage image

to be displayed through the same product UI.

Do not create two completely separate product systems.

---

## 61. Asset Management

Preloaded application assets should be referenced through Flutter's asset system.

The AI must tell the developer when an asset needs to be added to:

`pubspec.yaml`

The AI must not assume that simply placing an image into a folder automatically makes it available to Flutter.

---

## 62. Firebase Configuration Files

Firebase configuration should follow the official FlutterFire setup process.

The developer will perform the required terminal configuration.

The AI may provide the commands and explain the expected result.

The AI must not invent Firebase credentials.

---

## 63. Terminal Commands

The AI may provide terminal commands when required.

Examples:

- `flutter pub add firebase_core`
- `flutter pub add cloud_firestore`
- `flutter pub add firebase_auth`
- `flutter pub add firebase_storage`
- `flutterfire configure`

The developer is responsible for running these commands.

The AI should explain:

- Where to run the command.
- Why it is needed.
- What should happen after running it.

---

## 64. Firebase Console Configuration

Some Firebase functionality requires configuration outside the Dart code.

Examples may include:

- Enabling Authentication providers
- Creating/configuring Firestore
- Configuring Storage
- Configuring Cloud Messaging
- Deploying Security Rules

When this is required, the AI must clearly tell the developer that the action must be performed in the Firebase Console or terminal.

Do not pretend that a Dart file alone completes Firebase configuration.

---

## 65. Dependencies

The AI should not install packages without a reason.

Before adding a package, determine:

- Why it is needed.
- Whether Flutter/Firebase already provides the required functionality.
- Whether an existing project dependency can solve the problem.

Avoid dependency bloat.

---

## 66. State Management Dependency

Provider is the planned state-management solution.

If the project already contains another state-management system before implementation begins, the AI should inspect the existing architecture before replacing it.

Do not replace an existing architecture without a documented reason.

---

## 67. No Unnecessary Framework Changes

The AI must not:

- Replace Flutter with another framework.
- Replace Firebase with another backend.
- Replace Provider without reason.
- Rewrite the entire application architecture because of one feature.
- Add an unrelated architecture pattern.

The existing project documentation is the source of truth.

---

## 68. Code Generation Behavior

When asked to implement a feature, the AI should:

- Read the relevant MD files.
- Inspect the current project.
- Identify existing related files.
- Explain which files need to be created or modified.
- Create or provide the required Dart code.
- Clearly identify any terminal commands.
- Clearly identify any Firebase Console changes.
- Avoid modifying unrelated files.

---

## 69. Do Not Blindly Rewrite Files

The AI must not overwrite a large existing Dart file without first inspecting it.

Before replacing existing code, determine:

- What functionality already exists.
- What can be reused.
- What must be changed.
- Whether the change could break another feature.

Prefer incremental changes.

---

## 70. Architecture Changes

If a requested feature cannot reasonably fit into the current architecture, the AI should explain:

- Why the current structure is insufficient.
- What change is being proposed.
- Which files would be affected.
- Whether existing functionality could be affected.

The AI should not silently restructure the entire project.

---

## 71. Development Workflow

The recommended development workflow is:

- 1. Developer creates Flutter project.
- 2. Developer configures Firebase.
- 3. AI reads project MD files.
- 4. AI inspects existing Flutter project.
- 5. AI implements one feature at a time.
- 6. Developer runs the application.
- 7. Developer tests the feature.
- 8. Problems are reported to AI.
- 9. AI diagnoses and proposes changes.
- 10. Continue to the next feature.

Do not attempt to blindly generate the entire application in one step.

---

## 72. Feature Implementation Order

The exact order may change based on development needs, but a reasonable implementation sequence is:

- 1. Flutter project setup
- 2. Firebase connection
- 3. Authentication
- 4. User profile
- 5. Main navigation
- 6. Product models/data
- 7. Product browsing
- 8. Product details
- 9. Search/filtering
- 10. Cart
- 11. Checkout
- 12. Orders
- 13. Order status
- 14. Reviews
- 15. Refund requests
- 16. Notifications
- 17. Admin product management
- 18. Admin order management
- 19. Admin refund management
- 20. Testing and security review
- 21. APK build

The AI should not assume every feature must be implemented in exactly this order if dependencies require another sequence.

---

## 73. Testing During Development

The developer should test features progressively.

After implementing a feature, verify:

- UI behavior
- Firebase behavior
- Authentication behavior
- Security behavior
- Error handling
- Loading states
- Different screen sizes
- Invalid input
- Edge cases

Do not wait until the entire application is finished before testing.

---

## 74. Security Testing

Security testing should include attempts such as:

- Customer attempting to access another customer's order.
- Customer attempting to modify product data.
- Customer attempting to change their role.
- Customer attempting to modify stock.
- Customer attempting to approve a refund.
- Customer attempting to review an undelivered order.
- Customer attempting to cancel a shipped order.
- Customer attempting to manipulate prices.
- Customer attempting to access admin functionality.

Security must be enforced at Firebase/backend levels, not only through UI.

---

## 75. Performance

The application should avoid unnecessary:

- Firestore reads
- Firestore writes
- Widget rebuilds
- Image downloads
- Repeated network requests

Use appropriate caching and state management when reasonable.

Do not over-optimize prematurely.

The goal is a responsive school application with understandable code.

---

## 76. Maintainability

The architecture should make it easy to locate code.

For example:

If the developer wants to change Product UI, they should primarily look in:

`features/products/`

If they want to change Firestore product operations, they should primarily look in:

`services/firestore/`

If they want to change Product data structure, they should primarily look in:

`models/`

If they want to change Global theme, they should primarily look in:

`core/theme/`

---

## 77. Documentation Consistency

The AI must treat the project MD files as a connected documentation system.

The AI should not interpret one document in isolation when another document provides relevant requirements.

Relevant documentation includes:

- `00_RULES.md`
- `01_FEATURES.md`
- `02_UI_UX.md`
- `03_FIREBASE.md`
- `05_ARCHITECTURE.md`

The AI should identify conflicts between documents instead of silently ignoring them.

Architecture decisions should not override explicit security or functional requirements.

---

## 78. AI Must Explain Structural Changes

When creating or modifying architecture, the AI should explain:

- What files are being created.
- What each file is responsible for.
- Why the file belongs in that location.
- What terminal commands are required.
- What Firebase Console configuration is required.

The explanation should be understandable to a developer who is still learning Flutter.

---

## 79. AI Must Not Hide Required Manual Steps

If something must be done manually by the developer, the AI must clearly say so.

Examples include:

- Manual terminal commands.
- Firebase Console configuration.
- Adding assets to `pubspec.yaml`.
- Creating Firebase Security Rules.
- Running Flutter commands.
- Running the application and testing.

The AI must not claim that creating a Dart file automatically performs these actions.

---

## 80. AI Coding Scope

The AI is allowed to:

- Create Dart files.
- Modify Dart files.
- Explain where files belong.
- Suggest folder structures.
- Provide terminal commands.
- Explain Firebase Console configuration.
- Create models.
- Create providers.
- Create services.
- Create screens.
- Create reusable widgets.
- Diagnose errors.
- Refactor code when necessary.

The AI must remain within the documented architecture.

The AI should not attempt to create the entire Flutter project structure through generated text and assume it has been created.

The developer will create and manage the actual Flutter project and folders through the terminal/file system.

---

## 81. Developer Responsibilities

The developer is responsible for:

- Creating the Flutter project.
- Running terminal commands.
- Configuring Firebase accounts/projects.
- Performing Firebase Console configuration.
- Managing project credentials.
- Testing the application.
- Confirming that generated code works.
- Building the APK.
- Deciding whether proposed architecture changes should be accepted.

The AI assists with implementation but does not replace developer control.

---

## 82. No Fake Functionality

The AI must not create fake backend functionality and present it as real.

For example, do not create a fake function that says:

`Payment successful`

when no real payment system has processed the payment.

Do not create a fake refund confirmation claiming that money was returned when only a refund request was submitted.

Demo behavior must be clearly separated from real backend functionality.

---

## 83. School Project Consideration

This is a school project.

The architecture should demonstrate good development practices without becoming unnecessarily complicated.

The code should remain understandable enough that the developer can explain:

- What each folder does.
- What Firebase does.
- What a provider does.
- What a service does.
- What a model does.
- How data flows from Flutter to Firebase.
- How authentication works.
- How authorization works.

Avoid architecture that exists only to look advanced.

---

## 84. Final Architecture Principle

The Trend Kicks architecture should follow this principle:

- Simple enough to understand.
- Structured enough to maintain.
- Secure enough to protect data.
- Flexible enough to add features.
- Consistent with the Figma design.
- Consistent with Firebase.
- Appropriate for a school e-commerce application.

The AI must prioritize clarity, maintainability, security, and consistency over unnecessary complexity.

The architecture must support the functionality defined in `01_FEATURES.md`, the design defined in `02_UI_UX.md`, and the Firebase requirements defined in `03_FIREBASE.md`.