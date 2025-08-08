## Dynasty

An open-source iOS app to preserve and share family history across generations. Dynasty combines a secure vault for documents and media with an interactive family tree and collaborative history book.

### Highlights

- Biometric auth (Face ID/Touch ID)
- Secure vault with end-to-end encryption
- Interactive family tree
- History book with media
- SwiftUI-first architecture

### Requirements

- Xcode 15+
- iOS 17+
- Swift 5.9+

### Quick Start

1. Clone the repo
2. Create a Firebase project (iOS app)
3. Download your `GoogleService-Info.plist`
4. Place it at `dynasty/Resources/GoogleService-Info.plist` (not committed)
5. Open `dynasty.xcodeproj` and Run

See `dynasty/Resources/GoogleService-Info.example.plist` for the expected format. The real file is ignored by git.

### Features

- Secure Vault: encrypted storage, thumbnails, progress tracking, recycle bin
- Family Tree: member management, relationships, visualization
- History Book: stories, comments, media, timeline

### Architecture

- SwiftUI + MVVM
- Firebase Auth/Firestore/Storage
- Keychain-based key management
- Local SQLite cache

### Development

- Use `// MARK:` to organize source files
- Document public APIs with `///`
- Handle errors explicitly and surface actionable messages

### Firebase Storage Rules Example

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

### Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) and our [Code of Conduct](CODE_OF_CONDUCT.md).

### Security

Never commit secrets. The Firebase plist is ignored by default. See [SECURITY.md](SECURITY.md) for reporting vulnerabilities and cleaning history.

### License

MIT © 2025 Ruchit Patel. See [LICENSE](LICENSE).
