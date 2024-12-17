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
│       └── FirestoreManager.swift
│
├── Features/
│   ├── Authentication/
│   │   └── Services/
│   │       └── AuthManager.swift
│   ├── FamilyTree/
│   ├── Feed/
│   ├── HistoryBook/
│   ├── Profile/
│   │   ├── Models/
│   │   │   └── User.swift
│   │   ├── Services/
│   │   │   ├── AnalyticsService.swift
│   │   │   ├── CacheService.swift
│   │   │   ├── ErrorHandlingService.swift
│   │   │   └── ValidationService.swift
│   │   ├── ViewModels/
│   │   │   ├── ProfileViewModel.swift
│   │   │   ├── UserProfileEditViewModel.swift
│   │   │   └── UserSettingsManager.swift
│   │   └── Views/
│   │       ├── Components/
│   │       │   └── SettingsComponents.swift
│   │       ├── AppearanceView.swift
│   │       ├── HelpSupportView.swift
│   │       ├── NotificationsView.swift
│   │       ├── PrivacySecurityView.swift
│   │       ├── UserProfileEditView.swift
│   │       └── ProfileView.swift
│   └── Vault/
│       ├── Models/
│       │   └── VaultItem.swift
│       ├── Services/
│       │   ├── VaultManager.swift
│       │   ├── DatabaseManager.swift
│       │   ├── FirebaseStorageService.swift
│       │   ├── VaultEncryptionService.swift
│       │   └── ThumbnailService.swift
│       └── Views/
│           ├── VaultView.swift
│           ├── VaultContentView.swift
│           ├── VaultItemDetailView.swift
│           ├── VaultItemThumbnailView.swift
│           ├── TrashView.swift
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
├── Config/
│   ├── storage.rules
│   └── GoogleService-Info.plist
│
└── Preview Content/
    └── Preview Assets.xcassets/
```

