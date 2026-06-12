# Security Policy for Android Project Generator

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| latest  | ✅ Active support  |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in the Android Project Generator script or the projects it generates, please report it privately.

**Do not** open a public GitHub issue for security vulnerabilities.

### How to Report

1. Open a [private security advisory](https://github.com/MaheshTechnicals/android-project-generator/security/advisories/new) on GitHub
2. Or email the project maintainer directly via the GitHub profile

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if applicable)

### Response Timeline

- **Acknowledgment**: within 48 hours
- **Assessment**: within 5 business days
- **Fix timeline**: communicated after assessment

## Security Best Practices for Generated Projects

The generated Android projects include security-conscious defaults:

- **ProGuard/R8** minification and shrinking enabled for release builds
- **META-INF** exclusions for AL2.0/LGPL2.1 license conflicts
- **Debug builds** use `.debug` application ID suffix (never accidentally ship debug builds)
- **Keystore** is never committed to the repository (`.gitignore` blocks `*.keystore` and `*.jks`)
- **CI/CD secrets** are injected via environment variables, never hardcoded

## Scope

This policy covers:
- The `create-android-app.sh` script
- Generated project templates and build configurations
- GitHub Actions and GitLab CI pipeline definitions

Third-party dependencies fetched at runtime (AGP, Kotlin, Gradle, etc.) follow their own security policies.
