# Seller Dashboard Implementation Guide

## Overview
A complete seller dashboard system has been implemented with full CRUD operations for product management, image upload with auto-resizing, and database integration for buyer visibility.

## Components Implemented

### 1. **Product Model Updates** (`lib/models/product.dart`)
Enhanced the Product model with new fields:
- `description` (String): Detailed product description
- `availabilityStatus` (AvailabilityStatus enum): Product availability status
  - `available`: Product is currently available for purchase
  - `outOfStock`: Product is out of stock
  - `archived`: Product is archived/delisted
- `sellerId` (String?): Seller identifier for filtering products

**Updated enums:**
- New: `AvailabilityStatus` with three states

### 2. **ImageService** (`lib/services/image_service.dart`)
Complete image handling service with:

#### Key Methods:
- `pickImageFromGallery()`: Opens device gallery for image selection
- `pickImageFromCamera()`: Opens device camera for photo capture
- `uploadAndResizeImage()`: 
  - Resizes image to 400x400 pixels
  - Converts to PNG format
  - Uploads to Firebase Storage
  - Returns download URL
- `deleteImage()`: Removes image from Firebase Storage

#### Image Processing:
- Uses the `image` package for image manipulation
- Automatic PNG encoding with 400x400 resolution
- Named file storage: `products/{sellerId}/{productId}_{timestamp}.png`

### 3. **ProductService Updates** (`lib/services/product_service.dart`)
Enhanced with new parameters:
- `addProduct()`: Now requires `description` and `availabilityStatus`
- `updateProduct()`: Now supports updating `description` and `availabilityStatus`
- `_productFromDoc()`: Updated to parse new fields from Firestore

### 4. **AddEditProductDialog Widget** (`lib/widgets/add_edit_product_dialog.dart`)
Comprehensive dialog for creating and editing products:

#### Features:
- **Image Management**:
  - Image picker UI with visual feedback
  - Display existing image or new selection
  - 200x200px preview
  - Tap to change image

- **Form Fields**:
  - Product name (required)
  - Description (required, 3 lines)
  - Category dropdown (Hair, Body, Clothes, Accessories, Other)
  - Price field with decimal support
  - Condition dropdown (New/Used)
  - Availability status dropdown
  - Auction checkbox

- **Image Upload**:
  - Automatic 400x400 resizing
  - URL generation and storage
  - Old image deletion on update
  - Error handling with user feedback

#### Form Validation:
- All required fields must be filled
- New products require an image
- Price must be a valid number
- Loading states prevent multiple submissions

### 5. **SellerDashboardScreen** (`lib/screens/seller_dashboard_screen.dart`)
Main dashboard displaying seller's products:

#### Features:
- **Product List View**:
  - Product image (100x100px)
  - Title, category, and price display
  - Condition badge
  - Availability status (color-coded)
  - Auction indicator
  - Description preview

- **Product Card**:
  - Image thumbnail
  - Full product details
  - Status indicators
  - Edit and Delete buttons

- **Status Badges**:
  - **Green**: Available
  - **Orange**: Out of Stock
  - **Grey**: Archived
  - **Blue**: Auction enabled

- **CRUD Operations**:
  - Create: FAB button opens AddEditProductDialog
  - Read: Real-time list display
  - Update: Edit button opens populated dialog
  - Delete: Confirmation dialog with image cleanup

- **Empty State**:
  - Friendly message for new sellers
  - Icon and call-to-action

- **Error Handling**:
  - User-friendly error messages
  - Snackbar notifications

### 6. **Integration with SellerHomeScreen**
The seller dashboard is integrated as the Dashboard tab (index 0) in the seller's home screen.

## Database Schema

### Firestore Structure: `products` collection
```
{
  "id": "auto-generated",
  "name": "string",
  "description": "string",
  "category": "string (Hair|Body|Clothes|Accessories|Other)",
  "price": "number",
  "condition": "number (0=newItem, 1=used)",
  "isAuctionEnabled": "boolean",
  "imageUrl": "string (Firebase Storage URL)",
  "sellerId": "string (Firebase Auth UID)",
  "availabilityStatus": "number (0=available, 1=outOfStock, 2=archived)",
  "createdAt": "timestamp"
}
```

## File Storage

### Firebase Storage Structure:
```
gs://bucket-name/products/{sellerId}/{productId}_{timestamp}.png
```

- All images are stored as PNG format
- Optimized to 400x400 pixels
- Automatically cleaned up when product is deleted

## Usage Flow

### Creating a Product:
1. Click the FAB (+) button on the dashboard
2. AddEditProductDialog opens
3. User fills in all required fields
4. User taps image area to select from gallery
5. Image is resized to 400x400 on upload
6. Product is saved to Firestore
7. Seller sees product in their list

### Editing a Product:
1. Click "Edit" button on product card
2. Dialog opens with pre-filled data
3. All fields can be modified
4. Selecting new image replaces old one (old image deleted)
5. Changes are saved to Firestore
6. List updates automatically

### Deleting a Product:
1. Click "Delete" button on product card
2. Confirmation dialog appears
3. Confirming deletion removes:
   - Product from Firestore
   - Associated image from Firebase Storage
4. Seller list updates immediately

## Dependencies Added

### pubspec.yaml
```yaml
image: ^4.1.0  # Image processing and resizing
```

Existing dependencies utilized:
- `firebase_storage: ^12.3.4` - Image storage
- `image_picker: ^1.0.4` - Device image selection
- `cloud_firestore: ^5.4.4` - Product database
- `firebase_auth: ^5.3.1` - Seller authentication

## Key Features

✅ **Image Optimization**: Automatic 400x400 resizing with PNG encoding
✅ **Database Integration**: Real-time Firestore sync for buyer visibility
✅ **Full CRUD**: Create, read, update, and delete products
✅ **Error Handling**: Comprehensive error messages and user feedback
✅ **Image Cleanup**: Automatic deletion of old images when updating
✅ **Status Management**: Track availability of products
✅ **Auction Support**: Mark products for weekly auctions
✅ **Real-time Sync**: Changes immediately visible to buyers

## Testing the Implementation

1. **Create Product**:
   - Navigate to seller dashboard
   - Click + button
   - Fill form and select image
   - Verify product appears in list
   - Check Firestore for product document
   - Check Firebase Storage for resized image

2. **Edit Product**:
   - Click Edit on any product
   - Modify fields and/or image
   - Verify changes in list and Firestore
   - Confirm old image is deleted from Storage

3. **Delete Product**:
   - Click Delete on any product
   - Confirm deletion
   - Verify product is removed from list
   - Verify document deleted from Firestore
   - Verify image deleted from Storage

4. **Buyer View** (if implemented):
   - Verify products appear on buyer home screen
   - Verify images load correctly from Firebase Storage
   - Verify pricing and availability status are correct

## Notes

- All timestamps use Firestore server time for consistency
- Product IDs are auto-generated by Firestore
- Seller ID is linked from Firebase Authentication
- Products filtered by seller ID in database queries
- Images are accessible to buyers via direct Firebase Storage URLs
- Error handling prevents data loss and provides user feedback
