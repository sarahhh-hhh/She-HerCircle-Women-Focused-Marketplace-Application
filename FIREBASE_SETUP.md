/// Firebase Setup Guide for She&HerCircle
/// 
/// This guide will help you populate your Firestore database with products.
///
/// STEP 1: Add Firestore Rules
/// Go to Firestore Console > Rules and replace with:
/// 
/// ```
/// rules_version = '2';
/// service cloud.firestore {
///   match /databases/{database}/documents {
///     match /products/{document=**} {
///       allow read: if request.auth != null;
///       allow write: if request.auth != null && request.auth.uid == resource.data.sellerId;
///       allow create: if request.auth != null;
///     }
///     
///     match /users/{document=**} {
///       allow read: if request.auth != null && request.auth.uid == resource.id;
///       allow write: if request.auth != null && request.auth.uid == resource.id;
///     }
///   }
/// }
/// ```
///
/// STEP 2: Create test products in Firestore
/// Go to Firestore Console and add a "products" collection with these sample documents:
///
/// Document 1:
/// {
///   name: "Hydrating Shampoo",
///   category: "Hair",
///   price: 8.99,
///   condition: 0,
///   isAuctionEnabled: false,
///   imageUrl: "https://picsum.photos/seed/p1/200/200",
///   sellerId: "[USER_ID_1]"
/// }
///
/// Document 2:
/// {
///   name: "Deep Repair Conditioner",
///   category: "Hair",
///   price: 10.5,
///   condition: 0,
///   isAuctionEnabled: true,
///   imageUrl: "https://picsum.photos/seed/p2/200/200",
///   sellerId: "[USER_ID_2]"
/// }
///
/// Document 3:
/// {
///   name: "Body Lotion - Rose",
///   category: "Body",
///   price: 6.5,
///   condition: 0,
///   isAuctionEnabled: false,
///   imageUrl: "https://picsum.photos/seed/p3/200/200",
///   sellerId: "[USER_ID_1]"
/// }
///
/// Document 4:
/// {
///   name: "Summer Dress",
///   category: "Clothes",
///   price: 25.0,
///   condition: 1,
///   isAuctionEnabled: false,
///   imageUrl: "https://picsum.photos/seed/p5/200/200",
///   sellerId: "[USER_ID_2]"
/// }
///
/// Document 5:
/// {
///   name: "Gold Hoop Earrings",
///   category: "Accessories",
///   price: 15.0,
///   condition: 0,
///   isAuctionEnabled: false,
///   imageUrl: "https://picsum.photos/seed/p7/200/200",
///   sellerId: "[USER_ID_1]"
/// }
///
/// Where:
/// - condition: 0 = newItem, 1 = used
/// - sellerId: The UID of the seller user (sign up a seller and copy their UID from Firebase Auth)
///
/// STEP 3: Sign Up Users
/// 1. Run the app: flutter run
/// 2. Sign up as a Buyer: buyer_email@example.com / password123
/// 3. Sign up as a Seller: seller_email@example.com / password123
/// 4. Copy the User IDs from Firebase Console > Authentication > Copy UID
/// 5. Use these IDs as sellerId in the product documents
///
/// STEP 4: Test the App
/// - Login as Buyer and see all products
/// - Login as Seller and see your products
/// - Check real-time sync by adding products in Firestore Console
///
