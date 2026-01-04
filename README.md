# Kiri Hat - Hyperlocal Grocery Delivery Platform

A Flutter-based multi-vendor, on-demand grocery delivery application built with Firebase. Similar to apps like Blinkit, Zepto, or Swiggy Instamart.

## 🎯 Overview

**Kiri Hat** is a location-based grocery delivery platform operating on the "dark store" model. Customers order from the nearest vendor within a 15km radius and receive ultra-fast deliveries through a dedicated rider network.

## ✨ Key Features

### 🛒 Customer Features
- **Location-First Shopping**: GPS-based vendor assignment
- **Modern UI/UX**: Zepto/Blinkit-inspired design with green theme
- **Dynamic Home Page**: 
  - Clickable banner carousel with deep linking
  - Square category grid (3 columns)
  - Popular products section
  - Featured product grid
  - Dynamic sections controlled via Firestore
- **Category Navigation**:
  - Horizontal scrollable category tabs
  - Subcategory filtering via drawer
  - Subcategory-based product organization
- **Enhanced Search**: Searches across product name, brand, category, SEO title, tags, and keywords
- **Wishlist System**: Save favorite products with heart icon
- **Smart Cart System**: 
  - Vendor-specific carts with real-time updates
  - Floating cart button on all screens
  - Cart count badge
  - Single vendor cart enforcement
- **Product Features**:
  - Modern product detail screen with image carousel
  - Share product links (kirihat.com domain)
  - Add to wishlist
  - Real-time stock updates
  - Discount badges (only when MRP > price)
- **Flexible Delivery Options**:
  - Standard Delivery
  - Instant Delivery (20 minutes)
- **Multiple Payment Methods**: COD, UPI [phonpe UPI integration]
- **Address Management**: Save and manage multiple delivery addresses
- **Order Tracking**: Real-time status updates with delivery PIN verification

### 🏪 Vendor Features
- **Location-Based Discovery**: Set shop location for customer matching
- **Product Management**: 
  - Full CRUD with images, categories, stock tracking
  - **Image Upload Validation**:
    - Max dimensions: 1200x1200px (auto-resize)
    - Max file size: 2MB
    - Auto-compression before Cloudinary upload
    - Reduces platform costs significantly
  - **Subcategory Management**:
    - Create subcategories linked to parent categories
    - Dropdown selection with "Create New" button
    - Firestore-backed subcategory storage
  - Unit/variant field (e.g., 500g, 1L)
  - SEO fields (title, description)
  - Tags and search keywords
  - Brand information
  - Storage location tracking (aisle, shelf, bin)
- **Order Management**:
  - Barcode scanner for quick order lookup
  - Assign orders to riders
  - Generate PDF shipping labels with barcodes
  - Real-time order status tracking
- **Zone Management**: 
  - Dedicated screen for Service Area setup (`vendor_zones.dart`)
  - Integration with Pincode API for area lookup
  - Select specific post offices for delivery
  - Manage service areas independently from shop location
- **Rider Management**: Add, activate, and manage delivery partners
- **Earnings Dashboard**: Revenue tracking with commission breakdown
- **Settlement System**: Track rider payments and platform fees

### 🛵 Rider Features
- **Delivery Queue**: View assigned delivery jobs
- **Status Management**: Update delivery status in real-time
- **PIN Verification**: Secure delivery confirmation system
- **Earnings Tracking**: View per-delivery earnings with commission breakdown
- **Delivery History**: Complete trip history with settlement status

### 👨‍💼 Admin Features
- **User Management**: Create vendor, rider, and admin accounts
- **Platform Oversight**: Monitor all operations (expandable)
- **Home Layout Control**: Configure home screen sections (planned)

## 🏗️ Architecture

### Core Concept: Dark Store Model

```
Customer Location → Find Nearest Vendor (15km radius) → Show Vendor's Products → Order → Assign Rider → Deliver
```

### User Role Flow

```
┌──────────────┐
│ Login/Signup │
└──────┬───────┘
       │
┌──────▼────────┐
│  Auth Wrapper │ (Role-based routing)
└──────┬────────┘
       │
┌──────┼────────┬────────┐
│      │        │        │
Customer Vendor Rider  Admin
```

### Tech Stack

**Framework & Language**
- Flutter 3.x
- Dart 3.2.3+

**Backend & Database**
- Firebase Core 3.6.0
- Firebase Auth 5.3.1
- Cloud Firestore 5.4.4
- Firebase Storage 12.3.0

**UI Enhancement Packages**
- `cached_network_image` 3.3.0 - Efficient image caching
- `carousel_slider` 5.0.0 - Banner & image carousels
- `shimmer` 3.0.0 - Loading placeholders
- `flutter_rating_bar` 4.0.1 - Product ratings

**Key Packages**
- `geolocator` 13.0.1 - GPS & distance calculation
- `geocoding` 3.0.0 - Reverse geocoding
- `image_picker` 1.1.2 - Product image uploads
- `image` (native) - Image validation & compression
- `pdf` 3.10.4 - Shipping label generation
- `printing` 5.11.0 - PDF printing
- `intl` 0.19.0 - Date/time formatting
- `shared_preferences` 2.3.2 - Session management
- `pinput` 5.0.0 - PIN input UI
- `http` 1.2.2 - API calls
- `share_plus` 10.0.0 - Product sharing functionality
- `url_launcher` 6.3.0 - External links

## 📊 Database Structure (Firestore)

### Collections Overview

```
users/
  ├─ {uid}
  │   ├─ name, email, phone, role, current_address
  │   ├─ addresses/ (subcollection)
  │   │   └─ {addressId}: { name, phone, house_no, street, city, pincode, location }
  │   └─ wishlist/ (subcollection)
  │       └─ {productId}: { product_id, name, price, imageUrl, added_at }

vendors/
  └─ {vendorId}: { name, email, phone, location (GeoPoint), address, created_at }

vendor_settings/
  └─ {vendorId}: { min_order_value_free_delivery, ... }

vendor_zones/
  └─ {zoneId}
      ├─ vendor_id
      ├─ zone_name
      ├─ pincodes[] (array of strings)
      ├─ standard_fee
      └─ instant_fee

vendor_commission_settings/
  └─ {vendorId}
      ├─ base_commission
      ├─ distance_rate
      └─ delivery_fee_share

products/
  └─ {productId}
      ├─ vendor_id
      ├─ name, description
      ├─ price, mrp
      ├─ category, subcategory
      ├─ brand, unit
      ├─ stock_quantity
      ├─ images[] (array)
      ├─ imageUrl (fallback)
      ├─ tags[] (array)
      ├─ search_keywords[] (array)
      ├─ seo_title, seo_description
      ├─ storage_location { aisle, shelf, bin }
      ├─ isActive
      └─ created_at


categories/
  └─ {categoryId}: { name, sort_order, icon }

hero_categories/
  └─ {heroCategoryId}
      ├─ name
      ├─ icon_url
      ├─ category_ids[] (ordered array)
      ├─ position
      ├─ created_at
      └─ updated_at

subcategories/
  └─ {subcategoryId}
      ├─ name
      ├─ category_id
      ├─ icon_url
      ├─ created_at
      └─ updated_at

vendor_catalog_selections/
  └─ {vendorId}
      ├─ vendor_id
      ├─ hero_category_ids[] (array)
      └─ updated_at

banners/
  └─ {bannerId}
      ├─ imageUrl
      ├─ link_type: 'product' | 'category' | 'none'
      ├─ link_id: (product ID or category name)
      └─ order

master_products/
  └─ {productId}
      ├─ name, description
      ├─ category, subcategory
      ├─ brand, unit
      ├─ mrp
      ├─ images[] (array)
      ├─ imageUrl (fallback)
      ├─ tags[] (array)
      ├─ seo_title, seo_description
      ├─ barcode
      ├─ isActive
      └─ created_at

vendor_inventory/
  └─ {inventoryId}
      ├─ product_id (reference to master_products)
      ├─ vendor_id
      ├─ selling_price
      ├─ stock_quantity
      ├─ isAvailable
      ├─ last_updated
      └─ created_at

notifications/
  └─ {notificationId}
      ├─ recipient_id
      ├─ title
      ├─ message
      ├─ type: 'new_order' | 'order_cancelled' | 'order_delivered' | 'rider_cancelled'
      ├─ order_id
      ├─ isRead
      └─ timestamp

home_layout/
  └─ {sectionId}
      ├─ type: 'banner' | 'category_row' | 'product_row' | 'product_grid'
      ├─ title
      ├─ category_filter
      ├─ show_popular, show_featured, show_ads (boolean)
      └─ position

orders/
  └─ {orderId}
      ├─ order_id (short ID)
      ├─ customer_id, customer_phone
      ├─ vendor_id
      ├─ rider_id, rider_name, rider_phone
      ├─ items[] (array of product objects)
      ├─ delivery_address { name, phone, house_no, street, city, pincode }
      ├─ status: 'Pending' | 'Processing' | 'Shipped' | 'Delivered' | 'Cancelled'
      ├─ delivery_pin (4-digit OTP)
      ├─ delivery_mode: 'Standard' | 'Instant'
      ├─ payment_method: 'COD' | 'UPI'
      ├─ payment_status: 'Pending' | 'Paid'
      ├─ product_total, delivery_fee, total_amount
      ├─ rider_commission
      ├─ is_settled
      ├─ created_at, shipped_at, delivered_at
      └─ ...

riders/
  └─ {riderId}
      ├─ vendor_id
      ├─ name, phone
      ├─ status: 'Active' | 'Inactive'
      └─ created_at
```

## 🔄 Key Workflows

### Customer Order Flow

```
1. Open App → Location Gate (GPS or Manual)
2. Find Nearest Vendor (15km radius search)
3. Browse Products (vendor-specific catalog)
   - Use category tabs or search
   - Filter by subcategories
   - Add to wishlist (heart icon)
4. Add to Cart (floating cart button shows count)
5. Checkout:
   - Enter/Select Delivery Address
   - System validates pincode against vendor zones
   - Choose Delivery Mode (Standard/Instant)
   - Choose Payment Method (COD/UPI)
6. Place Order
7. Track Order Status
8. Verify Delivery PIN
9. Order Complete
```

### Vendor Order Processing Flow

```
1. Receive Order Notification
2. View Order Details
3. Scan Barcode or Search Order ID
4. Print Shipping Label (PDF with barcode)
5. Select Available Rider
6. Assign Order to Rider
7. System:
   - Deducts stock from inventory
   - Generates 4-digit delivery PIN
   - Updates order status to 'Shipped'
   - Notifies Rider
8. Track Delivery Status
9. Settlement & Commission Calculation
```

### Vendor Product Upload Flow

```
1. Navigate to Add Product
2. Fill Product Details:
   - General: Name, unit, description, brand
   - Choose category → Select/create subcategory
   - Add tags and SEO info
3. Upload Images (max 5):
   - System validates dimensions (max 1200x1200px)
   - Auto-compresses if > 2MB
   - Auto-resizes if too large
   - Uploads to Cloudinary
4. Set Pricing & Inventory
5. Configure Shipping Details
6. Save Product
```

## 💡 Core Logic Explanations

### Location-Based Vendor Matching

```dart
// customer_home.dart
1. Get customer's GeoPoint (lat, lng)
2. Fetch ALL vendors from Firestore
3. For each vendor:
   - Calculate distance using Geolocator.distanceBetween()
4. Find closest vendor within 15km radius
5. Set _nearestVendorId
6. Show ONLY that vendor's products
```

### Customer Product Visibility Logic

Why are some products hidden? The app enforces a strict **Location-Based Filtering** system to ensure customers only see actionable items.

1.  **Area Selection**:
    *   Customer selects a **Service Area** (Pincode/Zone) during onboarding or from the top bar.
    *   The system queries `vendor_zones` to find all **Vendor IDs** that serve this pincode.
    *   *Result*: A list of `available_vendor_ids` is stored in the user session.

2.  **Product Filtering**:
    *   Every product query (Home Screen, Category Page, Search) applies a filter:
    *   `where('vendor_id', whereIn: available_vendor_ids)`
    *   **Crucial Rule**: If a Vendor Account adds a product, but that Vendor is **not assigned** to the customer's currently selected Pincode Zone, the product will **NOT** appear.

3.  **Troubleshooting Visibility**:
    *   Ensure the Vendor has created a **Zone** in `Vendor Dashboard > Service Areas`.
    *   Ensure the Customer has selected a **Pincode** that falls within that Vendor's Zone.


### Enhanced Search System

```dart
// customer_category.dart
Search now includes:
- Product name
- Brand
- Category
- SEO title
- Tags (array)
- Search keywords (array)

// Example: Searching "organic" will match:
// - Name: "Organic Milk"
// - Brand: "Organic Valley"
// - Tags: ["organic", "fresh"]
// - Keywords: ["organic", "natural"]
```

### Image Validation & Compression

```dart
// utils/image_validation_helper.dart
1. Vendor selects image
2. Check file size (max 2MB)
3. Decode image and check dimensions
4. If width or height > 1200px:
   - Resize proportionally
5. Compress to 85% quality (JPEG)
6. Save compressed version
7. Upload to Cloudinary
// Result: Significant cost savings on Cloudinary
```

### Dynamic Home Page System

```dart
// Home screen layout is data-driven from Firestore
// Banners: Clickable with deep linking to products/categories
// Categories: Grid display with icons
// Products: Configurable sections (popular, featured)
```

### Smart Delivery Fee Calculation

```dart
// checkout_screen.dart
1. Customer enters pincode
2. Query vendor_zones where:
   - vendor_id = current vendor
   - pincodes array contains entered pincode
3. If zone found:
   - Get standard_fee and instant_fee
   - If order_total >= min_free_delivery → standard_fee = 0
4. Customer chooses delivery mode
5. Apply corresponding fee
```

### Wishlist Management

```dart
// product_detail.dart
1. User taps heart icon
2. Check if user is logged in
3. Save to users/{uid}/wishlist/{productId}
4. Store: product_id, name, price, imageUrl, timestamp
5. Icon changes to filled heart (red)
6. Can remove from wishlist by tapping again
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.2.3+)
- Firebase Project
- Android Studio / VS Code
- Git
- Cloudinary Account (for image hosting)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd kirihat
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable Authentication (Email/Password)
   - Enable Cloud Firestore
   - Enable Firebase Storage
   - Run FlutterFire CLI:
     ```bash
     flutterfire configure
     ```

4. **Cloudinary Setup**
   
   - Create account at [cloudinary.com](https://cloudinary.com)
   - Get your cloud name and upload preset
   - Update in `add_product_screen.dart`:
     ```dart
     Uri.parse("https://api.cloudinary.com/v1_1/YOUR_CLOUD_NAME/image/upload")
     ```

5. **Initial Data Setup**

   Create these Firestore collections manually:
   - `categories` - Add product categories with `icon` field
   - `banners` - Add banner images with linking
   - `subcategories` - Auto-created by vendors
   - `users`, `products`, `orders`, `vendors` - Auto-created during usage

6. **Create Admin User**

   Option A: Manual (Firebase Console):
   - Go to Authentication → Add user
   - Then add to Firestore `users/{uid}`:
     ```json
     {
       "email": "admin@kirihat.com",
       "name": "Admin",
       "role": "admin"
     }
     ```

   Option B: Use User Manager (in-app):
   - Login as admin
   - Use the User Manager screen to create vendors/riders

7. **Run the app**
   ```bash
   flutter run
   ```

## 🎨 File Structure

```
lib/
├── main.dart                    # App entry, AuthWrapper
├── user_manager.dart            # Create vendor/rider accounts
├── firebase_options.dart        # Firebase config
│
├── auth/
│   └── login_screen.dart        # Login/Signup with role routing
│
├── customer/
│   ├── customer_dashboard.dart  # Main container with Bottom Navigation & PopScope
│   ├── location_gate.dart       # GPS permission & location setup
│   ├── customer_home.dart       # Modern home with banners, categories, products
│   ├── customer_category.dart   # Category browser with tabs & subcategories
│   ├── customer_orders.dart     # Order history
│   ├── customer_profile.dart    # Profile & settings
│   ├── cart_screen.dart         # Shopping cart
│   ├── checkout_screen.dart     # Zone validation & payment
│   ├── product_detail.dart      # Modern product detail with share & wishlist
│   ├── address_screen.dart      # Add/Edit delivery addresses
│   ├── manage_addresses.dart    # Address list
│   └── order_details.dart       # Order tracking & details
│
├── vendor/
│   ├── vendor_dashboard.dart    # Bottom nav wrapper
│   ├── vendor_home.dart         # Stats & quick actions
│   ├── vendor_inventory.dart    # Product list
│   ├── add_product_screen.dart  # Create/Edit products with image validation
│   ├── vendor_orders.dart       # Order management & rider assignment
│   ├── vendor_earnings.dart     # Revenue dashboard
│   ├── vendor_settlements.dart  # Rider payment tracking
│   ├── vendor_profile.dart      # Settings
│   ├── vendor_location_setup.dart # Shop Profile Setup (Address, GPS)
│   ├── vendor_zones.dart        # Service Area Management (Pincodes, Zones)
│   ├── vendor_riders.dart       # Rider management
│   ├── category_screen.dart     # Category management
│   └── ...
│
├── rider/
│   ├── rider_dashboard.dart     # Bottom nav wrapper
│   ├── rider_home.dart          # Today's stats
│   ├── rider_orders.dart        # Active deliveries
│   ├── rider_history.dart       # Past deliveries
│   ├── rider_earnings.dart      # Earnings breakdown
│   └── rider_profile.dart       # Settings
│
├── admin/
│   └── admin_dashboard.dart     # Admin panel (basic)
│
├── utils/
│   ├── app_colors.dart          # Green theme colors
│   ├── cart_helper.dart         # Cart management utility
│   └── image_validation_helper.dart # Image validation & compression
│
└── widgets/
    ├── order_timer.dart         # Delivery countdown timer
    ├── product_card.dart        # Zepto-style product card
    ├── category_grid_card.dart  # Square category card
    └── footer_section.dart      # Home page footer
```

## 🔐 User Roles & Permissions

| Role     | Can Access                              | Default Signup |
|----------|----------------------------------------|----------------|
| Customer | Browse, Order, Track, Wishlist          | ✅ Yes         |
| Vendor   | Manage Products, Orders, Riders, Zones  | ❌ Admin only  |
| Rider    | Accept Deliveries, Update Status        | ❌ Vendor only |
| Admin    | Create Users, Platform Management       | ❌ Manual      |

## 📱 Supported Platforms

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 🎯 Business Model

1. **Platform Commission**: Vendor pays X% per order
2. **Delivery Fees**: Vendor sets fees (Standard/Instant)
3. **Rider Earnings**: Base fee + distance-based rate
4. **Zone-Based Pricing**: Dynamic fees per area

## 🔧 Configuration

Key settings in Firestore:

```javascript
// vendor_settings/{vendorId}
{
  "min_order_value_free_delivery": 199  // Orders above this get free standard delivery
}

// vendor_commission_settings/{vendorId}
{
  "base_commission": 30,        // Fixed amount per delivery
  "distance_rate": 10,          // ₹ per kilometer
  "delivery_fee_share": 0.5     // Platform's share of delivery fee (0-1)
}

// vendor_zones/{zoneId}
{
  "vendor_id": "vendor123",
  "zone_name": "Sector 15-18",
  "pincodes": ["560001", "560002", "560003"],
  "standard_fee": 29,
  "instant_fee": 49
}

// banners/{bannerId}
{
  "imageUrl": "https://...",
  "link_type": "product",     // or 'category' or 'none'
  "link_id": "product123",    // product ID or category name
  "order": 1                  // Display order
}
```

## 🆕 Recent Updates (v2.1)

### 🛠️ Refactoring & Architecture
- ✅ **Vendor Zone Management Refactor**:
  - Decoupled Service Area logic from Shop Profile
  - Pincode API integration for accurate area selection
  - Firestore-backed `service_areas` collection
- ✅ **Navigation Overhaul**:
  - Implemented `CustomerDashboard` with persistent Bottom Navigation
  - Smart Back Navigation using `PopScope`
  - Prevents accidental app closures
- ✅ **Authentication Flow**:
  - Seamless switching between Email and Mobile Auth
  - "Continue with Mobile Number" option on Login Screen
  - Improved OTP Timer and Back Navigation safety

### UI/UX Enhancements (v2.0)
- ✅ Zepto/Blinkit-inspired modern design
- ✅ Green theme throughout app (`#0D9759`)
- ✅ Floating cart button on all screens
- ✅ Horizontal category tabs
- ✅ Banner carousel with deep linking
- ✅ Modern product detail screen
- ✅ Wishlist with heart icon

### Feature Additions
- ✅ Share products via social media
- ✅ Wishlist management
- ✅ Enhanced multi-field search
- ✅ Subcategory management for vendors
- ✅ Image upload validation (dimensions & size)
- ✅ Auto-compression before Cloudinary upload
- ✅ Category icon support
- ✅ Product unit/variant field
- ✅ SEO fields for better discovery

### Technical Improvements
- ✅ `CartHelper` utility for consistent cart management
- ✅ `ImageValidationHelper` for upload optimization
- ✅ Firestore-backed wishlist
- ✅ Real-time cart count across screens
- ✅ Subcategory filtering via drawer
- ✅ Single vendor cart enforcement

## 🆕 Latest Updates (v3.0 - Hero Category Architecture)

### Phase 1-2: Database & Admin/Vendor Panels (✅ COMPLETED)

**New Architecture: Hero Categories → Categories → Subcategories**

#### Database Schema Updates
- ✅ `hero_categories` collection - Top-level product groupings
  - Fields: name, icon_url, category_ids[], position
  - Drag-to-reorder functionality
  - Cloudinary icon upload
- ✅ `subcategories` collection - Enhanced with icons
  - Fields: name, category_id, icon_url
  - Linked to parent categories
- ✅ `vendor_catalog_selections` collection
  - Stores vendor's selected hero categories
  - Fields: vendor_id, hero_category_ids[], updated_at

#### Admin Panel (Phase 1)
- ✅ **Hero Category Management** (`lib/admin/catalog/hero_category_management.dart`)
  - Create/Edit/Delete hero categories
  - Upload icons to Cloudinary
  - Assign multiple categories to hero category
  - Drag-and-drop reordering
  - Position management
- ✅ **Subcategory Management** (`lib/admin/catalog/subcategory_management.dart`)
  - Create subcategories under categories
  - Icon upload support
  - Category-based filtering
- ✅ **Cloudinary Service** (`lib/services/cloudinary_service.dart`)
  - Unified image upload service
  - Folder organization (hero_categories, subcategories, etc.)
  - Reusable across admin screens

**Admin Navigation Updates:**
- Added "Hero Categories" menu item
- Added "Subcategories" menu item
- Integrated routes in `admin_web_layout.dart`
- Updated `admin_sidebar.dart`

#### Vendor Panel (Phase 2)
- ✅ **Catalog Selection Screen** (`lib/vendor/catalog_selection_screen.dart`)
  - Beautiful card-based UI with hero category icons
  - Multi-select functionality
  - Visual selection feedback (checkboxes, borders, badges)
  - Save selections to Firestore
  - Load existing selections on init
  - Selection count display

**Vendor Navigation Updates:**
- Added "Catalog Selection" menu item (top of Inventory section)
- Integrated route in `vendor_dashboard.dart`
- Added page title in `vendor_header.dart`

### Phase 3-6: Customer Panel Redesign (⏳ IN PROGRESS)

#### Planned Customer Panel Changes
- [ ] **New Home Screen** (`lib/customer/home/customer_home_screen.dart`)
  - Display vendor's selected hero categories
  - Grid/horizontal scroll layout with icons
  - Only show categories where vendor has inventory
  - Search bar integration
  - No vendor branding (area-based display)

- [ ] **Category Products Screen** (`lib/customer/category/category_products_screen.dart`)
  - Left sidebar with subcategory filters
  - Subcategory icon display
  - Product grid (2 columns)
  - Empty state handling
  - Floating cart integration

- [ ] **Product Detail Screen** (`lib/customer/product/product_detail_screen.dart`)
  - Multi-image carousel slider
  - Short & long description display
  - Related products section
  - Sticky bottom action bar:
    - "Add to Cart" button (left)
    - "Buy Now" button (right)

- [ ] **Floating Cart Widget** (`lib/customer/widgets/floating_cart_button.dart`)
  - Shows on: Home, Category, Product Detail
  - Badge with item count
  - Only visible when items > 0
  - Navigate to cart on tap

#### Vendor Inventory Enrichment System
- ✅ Created product enrichment service (`lib/services/home_layout_service.dart`)
  - Joins `vendor_inventory` + `master_products`
  - Merges: Product details from catalog + Vendor price/stock
  - `enrichInventoryWithProduct()` method
- ✅ Updated collection references:
  - Changed `products` → `master_products` (admin catalog)
  - `vendor_inventory` for stock & pricing
  - Customer sees merged data

### Recent Bug Fixes & Improvements
- ✅ Fixed product display using vendor inventory + master catalog join
- ✅ Updated category service to fetch from `master_products`
- ✅ Added debug logging for product visibility troubleshooting
- ✅ Cleaned up collection references across customer panel

### Notification System (✅ COMPLETED - Phase 13)
- ✅ Vendor notification panel (`lib/vendor/vendor_notifications_screen.dart`)
- ✅ Real-time badge for unread notifications
- ✅ Notification triggers:
  - New orders
  - Customer cancellations
  - Rider cancellations
  - Delivered orders
- ✅ Mark as read functionality
- ✅ Centralized `NotificationService`

### Area-Based Vendor Shopping (✅ COMPLETED - Phase 14)
- ✅ PIN-based area selection (`lib/customer/onboarding/pincode_gate.dart`)
- ✅ Vendor locked to customer's area
- ✅ Session persistence with `SharedPreferences`
- ✅ Auto-fill checkout address (PIN & Area locked)
- ✅ Dynamic category display based on vendor inventory

## 🐛 Known Issues / TODOs

### High Priority
- [ ] **Customer Panel Redesign** (Phases 3-6)
  - [ ] Implement new home screen with hero categories
  - [ ] Build category screen with subcategory sidebar
  - [ ] Create product detail screen with image slider
  - [ ] Add floating cart widget
  - [ ] Test complete user flow

### Medium Priority
- [ ] Payment gateway integration (currently UPI is placeholder)
- [ ] Push notifications for order updates
- [ ] Real-time rider location tracking
- [ ] Customer ratings & reviews
- [ ] Promotional codes & discounts
- [ ] Inventory low-stock alerts

### Low Priority / Future
- [ ] Analytics dashboard for admin
- [ ] Multi-language support
- [ ] Product comparison feature
- [ ] Wishlist screen for customers (currently only in product detail)
- [ ] Custom collections ("New Launch", "Trending")
- [ ] Advanced search filters

### Technical Debt
- [ ] Optimize Firestore queries with indexing
- [ ] Add Firebase security rules review
- [ ] Implement caching for hero categories
- [ ] Add loading states and error handling
- [ ] Create comprehensive test suite

## 📄 License

[Add your license here]

## 👥 Contributors

[Add contributors here]

## 📞 Support

For issues and questions:
- Email: [your-email]
- GitHub Issues: [repository-url/issues]
- Website: https://kirihat.com

---

**Built with ❤️ using Flutter & Firebase**
