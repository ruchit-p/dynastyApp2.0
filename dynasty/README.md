# Dynasty App 2.0

A secure family history and document management application.

## Project Status

### Core Features

#### Vault (🟢 Active Development)
The vault provides secure storage for sensitive family documents and media.

**Current Status:**
- ✅ Core vault functionality implemented
- ✅ Face ID/Touch ID authentication
- ✅ Secure document encryption/decryption
- ✅ Document management (upload, download, delete)
- ✅ Proper authentication flow and state management
- ✅ Memory optimization and database management
- ✅ Auto-locking on app background/tab switch
- ✅ Unified file view (documents, photos, videos)
- ✅ Search and filter functionality
- ✅ Progress tracking for file operations
- ✅ Video thumbnail generation and playback
- ✅ Recycling bin functionality
- ✅ Firebase Storage integration with proper error handling

**Authentication Flow:**
1. Default State:
   - Vault starts locked
   - Requires Face ID/device password for access
2. Access Flow:
   - User taps vault tab
   - Face ID/Touch ID prompt appears
   - On success: Shows vault contents
   - On cancel/fail: Returns to previous tab
3. Security Features:
   - Auto-locks when:
     - Switching tabs
     - App enters background
     - Session timeout
   - Requires re-authentication for each access
   - Secure key management
   - Data encryption at rest

**File Management:**
1. Upload:
   - Multiple file type support (documents, photos, videos)
   - Progress tracking
   - Automatic thumbnail generation
   - Type-specific handling
2. Storage:
   - Firebase Storage integration
   - User-specific storage paths
   - Secure file encryption
3. Interface:
   - Unified grid view for all files
   - Search functionality
   - Type filtering
   - Progress indicators
   - Thumbnail previews

**Recent Improvements:**
- Implemented unified file view
- Added search and filtering
- Added video support with thumbnails
- Improved file operation progress tracking
- Enhanced error handling
- Added recycling bin functionality
- Improved Firebase Storage integration

**Known Issues:**
- ⚠️ Large file handling needs optimization
- ⚠️ Video playback needs improvement
- ⚠️ Thumbnail caching could be optimized

**Next Steps:**
1. Performance Optimizations:
   - Implement thumbnail caching
   - Optimize large file handling
   - Add background upload support
2. Enhanced Features:
   - Add file sharing functionality
   - Implement file categorization/tags
   - Add batch operations
3. User Experience:
   - Add drag-and-drop support
   - Improve error messages
   - Add file preview functionality
4. Security:
   - Add file integrity checks
   - Implement version control
   - Add audit logging

#### Family Tree (🟡 In Planning)
- Basic tree visualization implemented
- Planning enhanced navigation and editing features

#### History Book (🟡 In Development)
- Basic story creation and viewing implemented
- Working on media integration and sharing

#### Feed (🟡 In Development)
- Basic feed functionality implemented
- Enhancing interaction features

### Technical Architecture

#### Security
- End-to-end encryption for vault contents
- Secure key storage using Keychain
- Biometric authentication integration
- Proper session management

#### Database
- SQLite for local storage
- WAL journaling mode
- Optimized query performance
- Proper connection management

#### Memory Management
- Autorelease pools for large operations
- Proper cleanup of sensitive data
- Optimized image handling
- Database connection pooling

#### Firebase Integration
- Secure storage rules
- User-specific storage paths
- Progress tracking
- Error handling

### Dependencies
- SwiftUI for UI
- LocalAuthentication for biometrics
- CryptoKit for encryption
- SQLite for local database
- Firebase for backend services
- AVFoundation for video handling

### Development Environment
- Xcode 15.0+
- iOS 17.0+
- Swift 5.9

## Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later
- CocoaPods

### Installation
1. Clone the repository
2. Run `pod install`
3. Open `Dynasty.xcworkspace`
4. Build and run

### Firebase Setup
1. Create a Firebase project
2. Add iOS app to the project
3. Download and add GoogleService-Info.plist
4. Update Storage Rules:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /vault/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## Contributing
Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.

## License
This project is licensed under the MIT License - see the LICENSE.md file for details 