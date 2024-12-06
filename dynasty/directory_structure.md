# Dynasty App Directory Structure

```
dynasty/
├── App/
│   ├── AppDelegate.swift
│   ├── DynastyApp.swift
│   └── Persistence.swift
│
├── Core/
│   ├── Components/
│   │   ├── ShareSheet.swift
│   │   └── PlusButtonModifier.swift
│   ├── Extensions/
│   │   └── UIImage+Extensions.swift
│   ├── Helpers/
│   │   └── KeychainHelper.swift
│   ├── Navigation/
│   │   └── ContentView.swift
│   └── Utils/
│
├── Features/
│   ├── Authentication/
│   │   └── Services/
│   │       └── AuthManager.swift
│   ├── FamilyTree/
│   ├── Feed/
│   ├── HistoryBook/
│   ├── Profile/
│   └── Vault/
│       ├── Extensions/
│       ├── Models/
│       │   └── VaultItem.swift
│       ├── Services/
│       │   ├── VaultManager.swift
│       │   ├── DatabaseManager.swift
│       │   ├── FirebaseStorageService.swift
│       │   ├── VaultEncryptionService.swift
│       │   └── ThumbnailService.swift
│       └── Views/
│           ├── VaultView.swift              # Main vault view with folder navigation
│           ├── VaultContentView.swift       # Content grid view with folder support
│           ├── VaultItemDetailView.swift    # Item detail view
│           ├── VaultItemThumbnailView.swift # Thumbnail view for items and folders
│           ├── TrashView.swift             # Trash management
│           └── Components/
│               ├── SearchFilterBar.swift
│               ├── SelectionOverlay.swift
│               ├── DocumentScannerView.swift
│               ├── FolderNavigationBar.swift
│               ├── FolderPathView.swift
│               └── FolderCreationView.swift
│
├── Resources/
│   ├── Assets.xcassets/
│   └── Info.plist
│
└── Preview Content/
    └── Preview Assets.xcassets/
```

## Directory Overview

### App/
Contains the main app entry points and core setup files.

### Core/
Houses reusable components, utilities, and helpers used across the app.
- **Components/**: Reusable UI components
- **Extensions/**: Swift extensions for added functionality
- **Helpers/**: Helper utilities and functions
- **Navigation/**: Navigation-related code
- **Utils/**: General utility functions

### Features/
Contains feature-specific modules, each in its own directory.

#### Vault/
The secure storage feature module:
- **Extensions/**: Vault-specific extensions
- **Models/**: Data models for vault items and folders
- **Services/**: Services for vault operations, including:
  - VaultManager: Main vault management service
  - DatabaseManager: Firestore database operations
  - FirebaseStorageService: Cloud storage operations
  - VaultEncryptionService: File encryption/decryption
  - ThumbnailService: Thumbnail generation and caching
- **Views/**: UI components and screens
  - Main views for vault functionality with folder support
  - Component views for specific UI elements
  - New folder-related components

### Resources/
Contains app resources like assets and configuration files.

### Preview Content/
Contains preview assets for SwiftUI previews in Xcode.