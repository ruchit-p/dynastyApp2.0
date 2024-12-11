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

