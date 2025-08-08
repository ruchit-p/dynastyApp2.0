# Security Policy

## Reporting a Vulnerability
Email security@mydynasty.app with details and steps to reproduce.

## Secrets and Credentials
- Do not commit credentials (API keys, tokens, certificates) to the repo
- `GoogleService-Info.plist` is excluded via `.gitignore`
- Use `dynasty/Resources/GoogleService-Info.example.plist` as a template

## Local Secrets Scan
```bash
brew install gitleaks || true
gitleaks detect --no-git --redact
```

## History Secrets Scan
```bash
gitleaks detect --redact --log-opts=--all
```

## Remove Sensitive Files From History
Rotate any leaked keys immediately, then rewrite history:
```bash
brew install git-filter-repo || true
# Remove the Firebase config across history
git filter-repo --path dynasty/Resources/GoogleService-Info.plist --invert-paths
```
After verifying locally, coordinate with collaborators and force-push:
```bash
git push origin --force --all && git push origin --force --tags
```
