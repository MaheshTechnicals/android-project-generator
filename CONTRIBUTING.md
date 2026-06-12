# Contributing to Android Project Generator

First off, thank you for considering contributing! Your help makes this tool better for everyone.

## Code of Conduct

By participating, you agree to maintain a respectful and inclusive environment for all contributors.

## How to Contribute

### 🐛 Report Bugs

Open an issue on [GitHub Issues](https://github.com/MaheshTechnicals/android-project-generator/issues) with:

- A clear, descriptive title
- Steps to reproduce
- Expected vs actual behavior
- OS and dependency versions (`java -version`, `bash --version`)

### 💡 Suggest Features

Open an issue with the **enhancement** label describing:

- What you want to add and why
- How it benefits users
- Any implementation ideas

### 🔧 Submit Code Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Test the script end-to-end
5. Commit with a clear message
6. Push and open a Pull Request

### 📝 Improve Documentation

Documentation improvements are always welcome — typos, clarifications, examples, translation fixes.

## Development Setup

```bash
git clone https://github.com/MaheshTechnicals/android-project-generator.git
cd android-project-generator
# No build step needed — it's a shell script
```

## Pull Request Checklist

- [ ] Script runs without errors: `bash create-android-app.sh`
- [ ] Generated project compiles: `cd /tmp/test-app && ./gradlew assembleDebug`
- [ ] Changes are backward compatible where possible
- [ ] Commit messages follow conventional commits format

## Style Guide

- Keep the script compatible with **Bash 4.3+** (no Bash 5-specific features)
- Use `set -euo pipefail` for safety
- Follow existing coding patterns (heredocs, helper functions, color output)
- Add comments for complex logic
- Keep functions focused and single-purpose

## Questions?

Open a [discussion](https://github.com/MaheshTechnicals/android-project-generator/discussions) — we're happy to help.

---

*Thank you for contributing to Android Project Generator!*
