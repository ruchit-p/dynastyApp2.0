# Dynasty App Directory Structure

## Features/
### Authentication/
#### Services/
- AuthManager.swift
#### Views/
- SignInView.swift
- SignUpView.swift

### Vault/
#### Models/
- VaultItem.swift
#### Services/
- VaultManager.swift
- VaultEncryptionService.swift
- FirebaseStorageService.swift
- DatabaseManager.swift
- ThumbnailService.swift
#### Views/
- VaultView.swift
- VaultItemDetailView.swift
- TrashView.swift

### Profile/
#### Models/
- User.swift

### FamilyTree/
#### Models/
- FamilyMember.swift
- FamilyTree.swift
- FamilyTreeNode.swift
- RelationType.swift
- Relationship.swift
#### Services/
- FamilyTreeManager.swift
#### ViewModels/
- FamilyTreeViewModel.swift
#### Views/
- AddFamilyMemberForm.swift
- AdminManagementView.swift
- Components/
  - ConnectionLine.swift
  - FamilyMemberNodeView.swift
  - PlusButtonsOverlay.swift
- FamilyTreeView.swift
- FamilyTreeVisualization.swift
- MemberSettingsView.swift
- SendInvitationView.swift

### Feed/
#### Models/
- Post.swift
#### ViewModels/
- FeedViewModel.swift

## App/
- AppDelegate.swift
- DynastyApp.swift
- Persistence.swift

## Core/
### Components/
- PlusButtonModifier.swift
- ShareSheet.swift
### Extensions/
- Codable+Dictionary.swift
### Helpers/
- KeychainHelper.swift
### Navigation/
- ContentView.swift
- MainTabView.swift
### Utils/
- Constants.swift

## Resources/
### Assets.xcassets/
- AccentColor.colorset/
- AppIcon.appiconset/
- tree.imageset/
- Contents.json
- GoogleService-Info.plist
- Info.plist
- dynasty.entitlements
### dynasty.xcdatamodeld/
- .xccurrentversion
- dynasty.xcdatamodel/

## Project Status/
- project_Status.txt
- directory_structure.md