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

**Recent Improvements:**
- Fixed authentication loop issues
- Improved navigation after document upload
- Enhanced state management for authentication
- Better memory handling and cleanup
- Proper database connection management
- Improved error handling and user feedback

**Known Issues:**
- ⚠️ Unsupported URL error for thumbnails
- ⚠️ Database integrity warning on rapid tab switches

**Next Steps:**
1. Implement thumbnail generation and caching
2. Add document preview functionality
3. Implement sharing features
4. Add document categorization
5. Implement search functionality

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

### Dependencies
- SwiftUI for UI
- LocalAuthentication for biometrics
- CryptoKit for encryption
- SQLite for local database
- Firebase for backend services

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

## Contributing
Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.

## License
This project is licensed under the MIT License - see the LICENSE.md file for details 