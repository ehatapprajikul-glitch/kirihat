# Kirihat Suite

Kirihat Suite is a comprehensive e-commerce ecosystem built with Flutter, consisting of three standalone applications sharing a common core.

## Project Structure

The project is organized as a monorepo with the following structure:

```
kirihat_suite/
├── kirihat_core/       # Shared logic, models, services, and utils
├── customer_app/       # Main shopping application for customers
├── rider_app/          # Delivery partner application
└── admin_portal/       # Web/Mobile portal for Admins, Vendors, and Sellers
```

### 1. Kirihat Core (`kirihat_core`)
A standalone Dart package that contains all the shared business logic, including:
- **Models**: Data classes (e.g., `ProductModel`, `OrderModel`, `UserModel`).
- **Services**: Firebase interactions and business logic (e.g., `AuthService`, `CartService`, `OrderService`).
- **Utils**: Helper functions and constants.

**Note**: All applications depend on `kirihat_core`. You must run `flutter pub get` in this directory if you modify dependencies here.

---

### 2. Customer App (`customer_app`)
The primary mobile application for customers to browse products, manage carts, and place orders.
- **Key Features**: Product browsing, Cart management, Checkout, Order tracking, User profile.

**Running the App:**
```bash
cd customer_app
flutter pub get
flutter run
```

---

### 3. Rider App (`rider_app`)
The application for delivery personnel to manage and fulfill orders.
- **Key Features**: Order requests, Delivery navigation, Earnings history, Status updates.
- **Auth**: Phone number authentication (Role: Rider).

**Running the App:**
```bash
cd rider_app
flutter pub get
flutter run
```

---

### 4. Admin Portal (`admin_portal`)
A unified dashboard for Administrators, Vendors, and Sellers to manage the platform.
- **Key Features**: Product management, Order processing, Inventory control, Analytics.
- **Roles**: Admin, Vendor, Seller.

**Running the App:**
```bash
cd admin_portal
flutter pub get
flutter run
```

## Setup Instructions

1.  **Prerequisites**:
    - Flutter SDK installed and configured.
    - Android Studio / VS Code with Flutter extensions.
    - Firebase project configured (ensure `firebase_options.dart` is present in each app's `lib/` folder).

2.  **Installation**:
    Go to the root of each application and install dependencies.
    ```bash
    # Install Core dependencies (Auto-resolved mostly, but good practice)
    cd kirihat_core
    flutter pub get
    
    # Install App dependencies
    cd ../customer_app
    flutter pub get
    
    cd ../rider_app
    flutter pub get
    
    cd ../admin_portal
    flutter pub get
    ```

3.  **Firebase Configuration**:
    Each application (`customer_app`, `rider_app`, `admin_portal`) requires its own `firebase_options.dart` file in `lib/firebase_options.dart`.

## Architecture Notes
- **Role-Based Routing**: Each app is configured with role-specific routing in `main.dart` and `login_screen.dart` to prevent unauthorized access (e.g., a Customer cannot log in to the Rider App).
- **Shared State**: Changes in `kirihat_core` affect all three apps. Be careful when modifying shared services.
