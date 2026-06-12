# Android Project Generator 🚀

**Create professional Android Kotlin + Jetpack Compose projects in seconds — right from your terminal.**

[![GitHub release](https://img.shields.io/github/v/release/MaheshTechnicals/android-project-generator?style=flat-square)](https://github.com/MaheshTechnicals/android-project-generator/releases)
[![License](https://img.shields.io/github/license/MaheshTechnicals/android-project-generator?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-linux-blue?style=flat-square)]()
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square)](CONTRIBUTING.md)

---

## 📖 Overview

**Android Project Generator** is a powerful Bash-based CLI tool that interactively scaffolds a complete, production-ready Android project with:

- ✅ **Kotlin** + **Jetpack Compose** (Material 3)
- ✅ **Gradle Kotlin DSL** with version catalog (`libs.versions.toml`)
- ✅ **Adaptive & legacy launcher icons** (auto-generated with ImageMagick)
- ✅ **Dual CI/CD** — GitHub Actions + GitLab CI pipelines
- ✅ **JUnit 4 + Espresso + Compose UI tests**
- ✅ **ProGuard** minification for release builds
- ✅ **Fastlane** metadata structure
- ✅ **Dynamic version fetching** — always gets latest stable AGP, Kotlin, Gradle, Compose BOM

No Android Studio needed. No IDE required. Just a terminal, Java, and a few seconds.

---

## 🧰 Requirements

The script requires the following dependencies installed on your Linux system:

```bash
sudo apt update && sudo apt install -y openjdk-21-jdk git curl python3 imagemagick
```

| Dependency       | Purpose                              | Required |
|------------------|--------------------------------------|----------|
| **Java 21+**     | Compile Android bytecode             | ✅ Yes   |
| **Git**          | Initialize repository                | ✅ Yes   |
| **curl**         | Fetch latest SDK tool versions       | ✅ Yes   |
| **Python 3**     | Parse Maven metadata XML             | ✅ Yes   |
| **ImageMagick**  | Generate launcher & Play Store icons | ⬜ No*   |

> \*ImageMagick is optional — without it, the script writes minimal placeholder PNGs so the build still succeeds.

---

## 🚀 Quick Start

```bash
# 1. Clone the generator
git clone https://github.com/MaheshTechnicals/android-project-generator.git
cd android-project-generator

# 2. Run it
bash create-android-app.sh

# 3. Follow the prompts — that's it!
```

### What You'll Be Asked

| Prompt               | Example                          |
|----------------------|----------------------------------|
| App Name             | `My Awesome App`                 |
| Package Name         | `com.example.myawesomeapp`       |
| Project Directory    | `my-awesome-app`                 |
| Min SDK              | `24` (Android 7.0, default)      |
| Git Remote URL       | `https://github.com/you/repo.git`|
| Logo PNG Path        | `/path/to/logo.png` (optional)   |
| Icon Background Color| `#FF5722` (default: white)       |

---

## 📦 What Gets Generated

```
my-app/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── kotlin/com/example/myapp/
│   │   │   │   ├── MainActivity.kt
│   │   │   │   └── ui/
│   │   │   │       ├── HelloWorldScreen.kt
│   │   │   │       └── theme/
│   │   │   │           ├── Theme.kt
│   │   │   │           ├── Color.kt
│   │   │   │           └── Type.kt
│   │   │   ├── res/
│   │   │   │   ├── drawable/
│   │   │   │   ├── mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/
│   │   │   │   ├── mipmap-anydpi-v26/
│   │   │   │   ├── values/
│   │   │   │   ├── layout/
│   │   │   │   └── xml/
│   │   │   └── AndroidManifest.xml
│   │   ├── test/kotlin/com/example/myapp/ExampleUnitTest.kt
│   │   └── androidTest/kotlin/com/example/myapp/ExampleInstrumentedTest.kt
│   ├── build.gradle.kts
│   └── proguard-rules.pro
├── gradle/
│   ├── wrapper/
│   └── libs.versions.toml
├── .github/workflows/android-ci.yml
├── .gitlab-ci.yml
├── fastlane/
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── gradlew
├── local.properties.template
├── .gitignore
└── README.md
```

---

## 🏗 Generated Project Architecture

### Build System
- **Gradle Kotlin DSL** with version catalog (`gradle/libs.versions.toml`)
- Centralized dependency management
- Configuration caching enabled
- Parallel builds enabled

### UI Layer
- **Material 3** design system with dynamic color support (Android 12+)
- Edge-to-edge rendering via `enableEdgeToEdge()`
- Dark/Light theme with automatic system detection
- Preview composable for Android Studio

### Testing
| Type              | Framework         | File                               |
|-------------------|-------------------|------------------------------------|
| Unit tests        | JUnit 4           | `ExampleUnitTest.kt`               |
| Instrumented tests| AndroidX Test     | `ExampleInstrumentedTest.kt`       |
| Compose UI tests  | Compose UI Test   | Built-in (via BOM)                 |

### CI/CD Pipelines

| Stage     | GitHub Actions                                   | GitLab CI                                         |
|-----------|--------------------------------------------------|---------------------------------------------------|
| Validate  | `lint`                                           | `lint`                                            |
| Test      | `test` (unit tests)                              | `unit-test`                                       |
| Build     | `assembleDebug` (debug), `assembleRelease` + `bundleRelease` (release) | Same                           |
| Release   | Auto GitHub Release on tag                       | Auto GitLab Release on tag                        |

---

## 🎨 Icon Generation

The script creates **5 density sets** for both legacy and adaptive icons:

| Density   | Legacy PNG | Adaptive Layer |
|-----------|------------|----------------|
| mdpi      | 48×48      | 108×108        |
| hdpi      | 72×72      | 162×162        |
| xhdpi     | 96×96      | 216×216        |
| xxhdpi    | 144×144    | 324×324        |
| xxxhdpi   | 192×192    | 432×432        |

Plus a **512×512 Play Store icon** in the `fastlane/` directory.

**Placeholder mode**: If no logo is provided, the script generates a Material-style gradient icon with the first letter of your app name.

---

## 🔧 Version Management

Versions are **auto-fetched** at runtime from official sources:

| Component  | Source                        |
|------------|-------------------------------|
| AGP        | Google Maven                  |
| Kotlin     | Maven Central                 |
| Gradle     | services.gradle.org API       |
| Compose BOM| Google Maven                  |
| core-ktx   | Google Maven                  |
| lifecycle  | Google Maven                  |
| activity-compose | Google Maven           |

Fallback hardcoded versions are used if the network is unavailable.

---

## 🧪 Usage Examples

### Create a project with a custom logo
```bash
bash create-android-app.sh
# At the prompt, provide: /home/user/logo.png
```

### Create a project with dark icon background
```bash
bash create-android-app.sh
# At the prompt, provide icon background: #212121
```

### Generate and push to remote in one go
```bash
bash create-android-app.sh
# At the prompt, provide the Git Remote URL
```

---

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 🔒 Security

Report security issues to the project's security advisory. See [SECURITY.md](SECURITY.md).

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 🙋 FAQ

**Q: Can I use this on macOS?**  
A: The script is designed for Linux. macOS support requires tweaks to dependency checks.

**Q: Do I need Android Studio?**  
A: No. The generated project can be built entirely from the command line.

**Q: Can I customize the generated code?**  
A: Yes! Fork the script and modify the heredoc templates to match your needs.

**Q: Will this work with older JDK versions?**  
A: Java 17+ is required. Java 21 is recommended and tested.

---

## ⭐ Support

If you find this project useful, please give it a ⭐ on [GitHub](https://github.com/MaheshTechnicals/android-project-generator)!

---

*Made with ♥ by [Mahesh Technicals](https://github.com/MaheshTechnicals)*
