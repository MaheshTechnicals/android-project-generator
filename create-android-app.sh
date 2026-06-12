#!/usr/bin/env bash
# ============================================================
#  Android Project Generator
#  create-android-app.sh
#
#  A powerful CLI tool to scaffold modern Android Kotlin +
#  Jetpack Compose projects instantly — like create-react-app
#  but for Android!
#
#  Author  : Mahesh Technicals
#  GitHub  : https://github.com/MaheshTechnicals/android-project-generator
#  Platform: Linux only
# ============================================================

set -euo pipefail

# ─── Versions (auto-fetched at runtime, hardcoded as fallback) ───────────────
AGP_VERSION="8.7.3"
GRADLE_VERSION="8.11.1"
KOTLIN_VERSION="2.1.0"
COMPOSE_BOM_VERSION="2024.12.01"
CORE_KTX_VERSION="1.15.0"
LIFECYCLE_VERSION="2.8.7"
ACTIVITY_COMPOSE_VERSION="1.9.3"
COMPOSE_UI_VERSION="1.7.6"
MIN_SDK="24"
TARGET_SDK="37"
COMPILE_SDK="37"
JAVA_VERSION="21"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Helpers ─────────────────────────────────────────────────────────────────
print_banner() {
  echo -e "${MAGENTA}"
  echo "  ╔═══════════════════════════════════════════════════╗"
  echo "  ║     🚀  Android Project Generator                ║"
  echo "  ║     Instant Kotlin + Compose Scaffold            ║"
  echo "  ║          by Mahesh Technicals                    ║"
  echo "  ║   github.com/MaheshTechnicals                    ║"
  echo "  ╚═══════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

step()    { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
success() { echo -e "${GREEN}  ✓ $1${RESET}"; }
warn()    { echo -e "${YELLOW}  ⚠ $1${RESET}"; }
error()   { echo -e "${RED}  ✗ $1${RESET}" >&2; }
info()    { echo -e "${BLUE}  ℹ $1${RESET}"; }

check_cmd() {
  command -v "$1" &>/dev/null
}

require_cmd() {
  if ! check_cmd "$1"; then
    error "'$1' not found. Please install it and retry."
    echo -e "  ${YELLOW}Install hint: $2${RESET}"
    exit 1
  fi
}

# ─── Fetch latest STABLE versions from authoritative sources ─────────────────
# Python-based filtering ensures alpha/beta/rc/eap are always excluded
_latest_stable_from_xml() {
  # Args: $1=xml_content
  # Extracts all <version> tags, removes non-stable, returns highest semver
  echo "$1" | python3 -c "
import sys, re
xml = sys.stdin.read()
versions = re.findall(r'<version>([^<]+)</version>', xml)
stable = [v for v in versions if not re.search(r'(?i)(alpha|beta|rc|eap|dev|milestone)', v)]
def ver_key(v):
    parts = re.split(r'[.\-]', v)
    result = []
    for p in parts:
        try: result.append((0, int(p)))
        except: result.append((1, p))
    return result
stable.sort(key=ver_key)
print(stable[-1] if stable else '')
" 2>/dev/null || true
}

fetch_latest_versions() {
  step "Fetching latest stable versions..."

  if ! check_cmd curl || ! check_cmd python3; then
    warn "curl/python3 not available — using hardcoded fallback versions"
    info "AGP=${AGP_VERSION}  Kotlin=${KOTLIN_VERSION}  Gradle=${GRADLE_VERSION}"
    return
  fi

  # Helper: fetch one Google Maven artifact version
  _fetch_google_maven() {
    local group_path="$1" artifact="$2"
    local xml
    xml=$(curl -sf --max-time 10 \
      "https://dl.google.com/dl/android/maven2/${group_path}/${artifact}/maven-metadata.xml" \
      2>/dev/null || true)
    [ -n "$xml" ] && _latest_stable_from_xml "$xml" || true
  }

  # Helper: fetch one Maven Central artifact version
  _fetch_maven_central() {
    local group_path="$1" artifact="$2"
    local xml
    xml=$(curl -sf --max-time 10 \
      "https://repo1.maven.org/maven2/${group_path}/${artifact}/maven-metadata.xml" \
      2>/dev/null || true)
    [ -n "$xml" ] && _latest_stable_from_xml "$xml" || true
  }

  # ── AGP: Google Maven ─────────────────────────────────────────────────────
  local v
  v=$(_fetch_google_maven "com/android/tools/build" "gradle")
  if [ -n "$v" ]; then
    AGP_VERSION="$v"; success "AGP: $AGP_VERSION  (stable ✓)"
  else
    warn "AGP fetch failed — using fallback ${AGP_VERSION}"
  fi

  # ── Kotlin: Maven Central ─────────────────────────────────────────────────
  v=$(_fetch_maven_central "org/jetbrains/kotlin" "kotlin-gradle-plugin")
  if [ -n "$v" ]; then
    KOTLIN_VERSION="$v"; success "Kotlin: $KOTLIN_VERSION  (stable ✓)"
  else
    warn "Kotlin fetch failed — using fallback ${KOTLIN_VERSION}"
  fi

  # ── Gradle: official version API ──────────────────────────────────────────
  local gradle_json
  gradle_json=$(curl -sf --max-time 10 \
    "https://services.gradle.org/versions/current" 2>/dev/null || true)
  if [ -n "$gradle_json" ]; then
    local fetched_gradle
    fetched_gradle=$(echo "$gradle_json" \
      | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])" \
      2>/dev/null || true)
    if [ -n "$fetched_gradle" ]; then
      GRADLE_VERSION="$fetched_gradle"
      success "Gradle: $GRADLE_VERSION  (stable ✓)"
    else
      warn "Gradle parse failed — using fallback ${GRADLE_VERSION}"
    fi
  else
    warn "Gradle fetch failed — using fallback ${GRADLE_VERSION}"
  fi

  # ── androidx.activity:activity-compose: Google Maven ─────────────────────
  v=$(_fetch_google_maven "androidx/activity" "activity-compose")
  if [ -n "$v" ]; then
    ACTIVITY_COMPOSE_VERSION="$v"; success "activity-compose: $ACTIVITY_COMPOSE_VERSION  (stable ✓)"
  else
    warn "activity-compose fetch failed — using fallback ${ACTIVITY_COMPOSE_VERSION}"
  fi

  # ── androidx.core:core-ktx: Google Maven ─────────────────────────────────
  v=$(_fetch_google_maven "androidx/core" "core-ktx")
  if [ -n "$v" ]; then
    CORE_KTX_VERSION="$v"; success "core-ktx: $CORE_KTX_VERSION  (stable ✓)"
  else
    warn "core-ktx fetch failed — using fallback ${CORE_KTX_VERSION}"
  fi

  # ── androidx.lifecycle:lifecycle-runtime-ktx: Google Maven ───────────────
  v=$(_fetch_google_maven "androidx/lifecycle" "lifecycle-runtime-ktx")
  if [ -n "$v" ]; then
    LIFECYCLE_VERSION="$v"; success "lifecycle: $LIFECYCLE_VERSION  (stable ✓)"
  else
    warn "lifecycle fetch failed — using fallback ${LIFECYCLE_VERSION}"
  fi

  # ── Compose BOM: Google Maven ─────────────────────────────────────────────
  v=$(_fetch_google_maven "androidx/compose" "compose-bom")
  if [ -n "$v" ]; then
    COMPOSE_BOM_VERSION="$v"; success "Compose BOM: $COMPOSE_BOM_VERSION  (stable ✓)"
  else
    warn "Compose BOM fetch failed — using fallback ${COMPOSE_BOM_VERSION}"
  fi

  # ── Latest stable Android SDK level: Google Maven platform list ───────────
  local sdk_xml
  sdk_xml=$(curl -sf --max-time 10 \
    "https://dl.google.com/dl/android/maven2/androidx/core/core-ktx/maven-metadata.xml" \
    2>/dev/null || true)
  if [ -n "$sdk_xml" ]; then
    # Fetch the latest core-ktx POM to read its compileSdkVersion requirement
    local latest_core_ktx
    latest_core_ktx=$(_latest_stable_from_xml "$sdk_xml")
    if [ -n "$latest_core_ktx" ]; then
      local pom_xml sdk_level
      pom_xml=$(curl -sf --max-time 10 \
        "https://dl.google.com/dl/android/maven2/androidx/core/core-ktx/${latest_core_ktx}/core-ktx-${latest_core_ktx}.pom" \
        2>/dev/null || true)
      sdk_level=$(echo "$pom_xml" | python3 -c "
import sys, re
pom = sys.stdin.read()
m = re.search(r'<compileSdkVersion>(\d+)</compileSdkVersion>', pom)
if m: print(m.group(1))
" 2>/dev/null || true)
      if [ -n "$sdk_level" ] && [ "$sdk_level" -ge "${COMPILE_SDK}" ] 2>/dev/null; then
        COMPILE_SDK="$sdk_level"
        TARGET_SDK="$sdk_level"
        success "SDK level: $COMPILE_SDK  (from core-ktx ${latest_core_ktx} ✓)"
      fi
    fi
  fi

  info "AGP=${AGP_VERSION}  Kotlin=${KOTLIN_VERSION}  Gradle=${GRADLE_VERSION}"
  info "activity-compose=${ACTIVITY_COMPOSE_VERSION}  core-ktx=${CORE_KTX_VERSION}  lifecycle=${LIFECYCLE_VERSION}"
  info "Compose BOM=${COMPOSE_BOM_VERSION}  compileSdk=${COMPILE_SDK}"
}


# ─── Dependency checks ───────────────────────────────────────────────────────
check_dependencies() {
  step "Checking system dependencies..."

  require_cmd "java"    "sudo apt install openjdk-21-jdk  OR  sdk install java 21-tem"
  require_cmd "python3" "sudo apt install python3"

  local java_ver
  java_ver=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
  if [ "$java_ver" -lt 17 ] 2>/dev/null; then
    warn "Java $java_ver detected. Java 17+ required. Continuing — update if build fails."
  else
    success "Java $java_ver ✓"
  fi

  # imagemagick for icon generation
  if check_cmd convert; then
    success "ImageMagick (convert) ✓"
    HAS_IMAGEMAGICK=true
  else
    warn "ImageMagick not found — icon generation will be skipped."
    warn "Install: sudo apt install imagemagick"
    HAS_IMAGEMAGICK=false
  fi

  # inkscape (optional, better SVG handling)
  if check_cmd inkscape; then
    HAS_INKSCAPE=true
  else
    HAS_INKSCAPE=false
  fi
}

# ─── User input ──────────────────────────────────────────────────────────────
collect_input() {
  echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}  Project Configuration${RESET}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

  # App name
  while true; do
    printf "\n  ${BOLD}App Name${RESET} (e.g. My Awesome App): "
    read -r APP_NAME
    APP_NAME=$(echo "$APP_NAME" | xargs)
    [ -n "$APP_NAME" ] && break
    error "App name cannot be empty."
  done

  # Derive safe module name
  APP_NAME_SAFE=$(echo "$APP_NAME" | tr ' ' '_' | tr -cd '[:alnum:]_' )
  DEFAULT_PKG=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '.' | tr -cd '[:alnum:].')
  DEFAULT_DIR=$(echo "$APP_NAME" | tr ' ' '-' | tr -cd '[:alnum:]-' | tr '[:upper:]' '[:lower:]')

  # Package name
  while true; do
    printf "  ${BOLD}Package Name${RESET} [com.example.${DEFAULT_PKG}]: "
    read -r PKG_INPUT
    PKG_NAME="${PKG_INPUT:-com.example.${DEFAULT_PKG}}"
    # Validate: at least 2 segments, only alnum/dots, no leading dots
    if echo "$PKG_NAME" | grep -qE '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){1,}$'; then
      break
    fi
    error "Invalid package name. Use format: com.company.appname (lowercase, dots)"
  done

  # Project directory
  printf "  ${BOLD}Project Directory${RESET} [./${DEFAULT_DIR}]: "
  read -r DIR_INPUT
  PROJECT_DIR="${DIR_INPUT:-${DEFAULT_DIR}}"

  # Min SDK
  printf "  ${BOLD}Min SDK${RESET} [${MIN_SDK}] (API 24 = Android 7.0): "
  read -r MIN_INPUT
  MIN_SDK="${MIN_INPUT:-${MIN_SDK}}"

  # Git remote (optional)
  printf "  ${BOLD}Git Remote URL${RESET} (leave blank to skip): "
  read -r GIT_REMOTE

  # Logo path (optional)
  printf "  ${BOLD}Logo PNG Path${RESET} (leave blank to use generated placeholder): "
  read -r LOGO_PATH_INPUT
  LOGO_PATH=$(echo "$LOGO_PATH_INPUT" | xargs)

  # Validate logo path
  if [ -n "$LOGO_PATH" ]; then
    if [ ! -f "$LOGO_PATH" ]; then
      warn "Logo file not found at '$LOGO_PATH' — will generate a placeholder."
      LOGO_PATH=""
    else
      success "Logo found: $LOGO_PATH"
    fi
  fi

  # Icon background color
  printf "  ${BOLD}Icon Background Color${RESET} [#FFFFFF] (hex, e.g. #FFFFFF white, #000000 black, #FF5722 orange): "
  read -r ICON_BG_INPUT
  ICON_BG_INPUT=$(echo "$ICON_BG_INPUT" | xargs)
  # Validate hex color format
  if echo "$ICON_BG_INPUT" | grep -qE '^#[0-9A-Fa-f]{6}$'; then
    ICON_BG_COLOR="$ICON_BG_INPUT"
  else
    ICON_BG_COLOR="#FFFFFF"
    if [ -n "$ICON_BG_INPUT" ]; then
      warn "Invalid color '$ICON_BG_INPUT' — using white (#FFFFFF)"
    fi
  fi
  info "Icon background: $ICON_BG_COLOR"

  echo ""
  echo -e "${BOLD}${GREEN}  ┌─────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${GREEN}  │         Project Summary                  │${RESET}"
  echo -e "${BOLD}${GREEN}  ├─────────────────────────────────────────┤${RESET}"
  printf   "${BOLD}${GREEN}  │${RESET}  %-38s ${BOLD}${GREEN}│${RESET}\n" "Name    : $APP_NAME"
  printf   "${BOLD}${GREEN}  │${RESET}  %-38s ${BOLD}${GREEN}│${RESET}\n" "Package : $PKG_NAME"
  printf   "${BOLD}${GREEN}  │${RESET}  %-38s ${BOLD}${GREEN}│${RESET}\n" "Dir     : $PROJECT_DIR"
  printf   "${BOLD}${GREEN}  │${RESET}  %-38s ${BOLD}${GREEN}│${RESET}\n" "Min SDK : $MIN_SDK"
  printf   "${BOLD}${GREEN}  │${RESET}  %-38s ${BOLD}${GREEN}│${RESET}\n" "Icon BG : $ICON_BG_COLOR"
  printf   "${BOLD}${GREEN}  │${RESET}  %-38s ${BOLD}${GREEN}│${RESET}\n" "AGP     : $AGP_VERSION"
  printf   "${BOLD}${GREEN}  │${RESET}  %-38s ${BOLD}${GREEN}│${RESET}\n" "Kotlin  : $KOTLIN_VERSION"
  printf   "${BOLD}${GREEN}  │${RESET}  %-38s ${BOLD}${GREEN}│${RESET}\n" "Gradle  : $GRADLE_VERSION"
  echo -e "${BOLD}${GREEN}  └─────────────────────────────────────────┘${RESET}"
  echo ""

  printf "  ${BOLD}Proceed? [Y/n]:${RESET} "
  read -r CONFIRM
  CONFIRM="${CONFIRM:-Y}"
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
}

# ─── Derive helper vars ───────────────────────────────────────────────────────
derive_vars() {
  # com.example.myapp → com/example/myapp
  PKG_PATH=$(echo "$PKG_NAME" | tr '.' '/')
  # Last segment of package = base activity name prefix
  APP_CLASS=$(echo "$PKG_NAME" | awk -F. '{print $NF}' | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
  # Sanitized app name for string resources (no quotes etc)
  APP_NAME_XML=$(echo "$APP_NAME" | sed "s/'/\\\\'/g")
}

# ─── Directory structure ──────────────────────────────────────────────────────
create_structure() {
  step "Creating project structure..."

  if [ -d "$PROJECT_DIR" ]; then
    warn "Directory '$PROJECT_DIR' already exists."
    printf "  Overwrite? [y/N]: "
    read -r OW
    [[ "$OW" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
    rm -rf "$PROJECT_DIR"
  fi

  local SRC="${PROJECT_DIR}/app/src"
  mkdir -p "${SRC}/main/kotlin/${PKG_PATH}/ui/theme"
  mkdir -p "${SRC}/main/res/drawable"
  mkdir -p "${SRC}/main/res/mipmap-anydpi-v26"
  mkdir -p "${SRC}/main/res/mipmap-mdpi"
  mkdir -p "${SRC}/main/res/mipmap-hdpi"
  mkdir -p "${SRC}/main/res/mipmap-xhdpi"
  mkdir -p "${SRC}/main/res/mipmap-xxhdpi"
  mkdir -p "${SRC}/main/res/mipmap-xxxhdpi"
  mkdir -p "${SRC}/main/res/layout"
  mkdir -p "${SRC}/main/res/values"
  mkdir -p "${SRC}/main/res/xml"
  mkdir -p "${SRC}/androidTest/kotlin/${PKG_PATH}"
  mkdir -p "${SRC}/test/kotlin/${PKG_PATH}"
  mkdir -p "${PROJECT_DIR}/gradle/wrapper"
  mkdir -p "${PROJECT_DIR}/.github/workflows"
  mkdir -p "${PROJECT_DIR}/.gitlab-ci"
  mkdir -p "${PROJECT_DIR}/buildSrc/src/main/kotlin"
  mkdir -p "${PROJECT_DIR}/fastlane/metadata/android/en-US/images"

  success "Directory structure created"
}

# ─── Gradle files ────────────────────────────────────────────────────────────
write_gradle_files() {
  step "Writing Gradle build files (Kotlin DSL)..."

  # gradle/wrapper/gradle-wrapper.properties
  cat > "${PROJECT_DIR}/gradle/wrapper/gradle-wrapper.properties" << EOF
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

  # gradlew (Linux)
  curl -sL "https://raw.githubusercontent.com/gradle/gradle/v${GRADLE_VERSION}/gradlew" \
    -o "${PROJECT_DIR}/gradlew" 2>/dev/null \
    || wget -qO "${PROJECT_DIR}/gradlew" \
       "https://raw.githubusercontent.com/gradle/gradle/v${GRADLE_VERSION}/gradlew" 2>/dev/null \
    || {
      # Fallback: write a minimal gradlew
      cat > "${PROJECT_DIR}/gradlew" << 'GRADLEW'
#!/bin/sh
exec "$(dirname "$0")/gradle/wrapper/gradle-wrapper.jar" "$@"
GRADLEW
    }
  chmod +x "${PROJECT_DIR}/gradlew"

  # Download gradle-wrapper.jar
  curl -sL "https://github.com/gradle/gradle/raw/v${GRADLE_VERSION}/gradle/wrapper/gradle-wrapper.jar" \
    -o "${PROJECT_DIR}/gradle/wrapper/gradle-wrapper.jar" 2>/dev/null || true

  # settings.gradle.kts
  # Use quoted heredoc ('GRADLE_SETTINGS') so bash does NOT process backslashes.
  # APP_NAME_SAFE is injected via sed after writing.
  cat > "${PROJECT_DIR}/settings.gradle.kts" << 'GRADLE_SETTINGS'
pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "APP_NAME_PLACEHOLDER"
include(":app")
GRADLE_SETTINGS
  # Inject actual app name
  sed -i "s/APP_NAME_PLACEHOLDER/${APP_NAME_SAFE}/" "${PROJECT_DIR}/settings.gradle.kts" 

  # build.gradle.kts (root)
  cat > "${PROJECT_DIR}/build.gradle.kts" << EOF
// Top-level build file — configuration for all sub-projects/modules
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose)      apply false
}
EOF

  # gradle/libs.versions.toml (version catalog)
  cat > "${PROJECT_DIR}/gradle/libs.versions.toml" << EOF
[versions]
agp              = "${AGP_VERSION}"
kotlin           = "${KOTLIN_VERSION}"
coreKtx          = "${CORE_KTX_VERSION}"
junit            = "4.13.2"
junitVersion     = "1.2.1"
espressoCore     = "3.6.1"
lifecycleRuntime = "${LIFECYCLE_VERSION}"
activityCompose  = "${ACTIVITY_COMPOSE_VERSION}"
composeBom       = "${COMPOSE_BOM_VERSION}"

[libraries]
androidx-core-ktx                    = { group = "androidx.core",              name = "core-ktx",                    version.ref = "coreKtx" }
junit                                = { group = "junit",                       name = "junit",                       version.ref = "junit" }
androidx-junit                       = { group = "androidx.test.ext",           name = "junit",                       version.ref = "junitVersion" }
androidx-espresso-core               = { group = "androidx.test.espresso",      name = "espresso-core",               version.ref = "espressoCore" }
androidx-lifecycle-runtime-ktx       = { group = "androidx.lifecycle",          name = "lifecycle-runtime-ktx",       version.ref = "lifecycleRuntime" }
androidx-activity-compose            = { group = "androidx.activity",           name = "activity-compose",            version.ref = "activityCompose" }
androidx-compose-bom                 = { group = "androidx.compose",            name = "compose-bom",                 version.ref = "composeBom" }
androidx-ui                          = { group = "androidx.compose.ui",         name = "ui" }
androidx-ui-graphics                 = { group = "androidx.compose.ui",         name = "ui-graphics" }
androidx-ui-tooling                  = { group = "androidx.compose.ui",         name = "ui-tooling" }
androidx-ui-tooling-preview          = { group = "androidx.compose.ui",         name = "ui-tooling-preview" }
androidx-ui-test-manifest            = { group = "androidx.compose.ui",         name = "ui-test-manifest" }
androidx-ui-test-junit4              = { group = "androidx.compose.ui",         name = "ui-test-junit4" }
androidx-material3                   = { group = "androidx.compose.material3",  name = "material3" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-compose      = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
EOF

  # app/build.gradle.kts
  cat > "${PROJECT_DIR}/app/build.gradle.kts" << EOF
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace  = "${PKG_NAME}"
    compileSdk = ${COMPILE_SDK}

    defaultConfig {
        applicationId   = "${PKG_NAME}"
        minSdk          = ${MIN_SDK}
        targetSdk       = ${TARGET_SDK}
        versionCode     = 1
        versionName     = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled   = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug") // swap with release key in CI
        }
        debug {
            applicationIdSuffix = ".debug"
            isDebuggable         = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_${JAVA_VERSION}
        targetCompatibility = JavaVersion.VERSION_${JAVA_VERSION}
    }

    kotlin {
        jvmToolchain(${JAVA_VERSION})
    }

    buildFeatures {
        compose    = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)

    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}
EOF

  success "Gradle files written"
}

# ─── Kotlin source files ──────────────────────────────────────────────────────
write_kotlin_sources() {
  step "Writing Kotlin source files..."

  local src="${PROJECT_DIR}/app/src/main/kotlin/${PKG_PATH}"

  # MainActivity.kt
  cat > "${src}/MainActivity.kt" << EOF
package ${PKG_NAME}

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.ui.Modifier
import ${PKG_NAME}.ui.theme.${APP_NAME_SAFE}Theme
import ${PKG_NAME}.ui.HelloWorldScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            ${APP_NAME_SAFE}Theme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    HelloWorldScreen(modifier = Modifier.padding(innerPadding))
                }
            }
        }
    }
}
EOF

  # HelloWorldScreen.kt
  cat > "${src}/ui/HelloWorldScreen.kt" << EOF
package ${PKG_NAME}.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import ${PKG_NAME}.R
import ${PKG_NAME}.ui.theme.${APP_NAME_SAFE}Theme

@Composable
fun HelloWorldScreen(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize(),
        verticalArrangement   = Arrangement.Center,
        horizontalAlignment   = Alignment.CenterHorizontally
    ) {
        Text(
            text  = stringResource(R.string.greeting),
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text  = stringResource(R.string.app_name),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Preview(showBackground = true, showSystemUi = true)
@Composable
fun HelloWorldScreenPreview() {
    ${APP_NAME_SAFE}Theme {
        HelloWorldScreen()
    }
}
EOF

  # Theme.kt
  cat > "${src}/ui/theme/Theme.kt" << EOF
package ${PKG_NAME}.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
    primary   = Purple80,
    secondary = PurpleGrey80,
    tertiary  = Pink80
)

private val LightColorScheme = lightColorScheme(
    primary   = Purple40,
    secondary = PurpleGrey40,
    tertiary  = Pink40
)

@Composable
fun ${APP_NAME_SAFE}Theme(
    darkTheme: Boolean            = isSystemInDarkTheme(),
    dynamicColor: Boolean         = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else      -> LightColorScheme
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            @Suppress("DEPRECATION")
            window.statusBarColor = colorScheme.primary.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography  = Typography,
        content     = content
    )
}
EOF

  # Color.kt
  cat > "${src}/ui/theme/Color.kt" << EOF
package ${PKG_NAME}.ui.theme

import androidx.compose.ui.graphics.Color

val Purple80      = Color(0xFFD0BCFF)
val PurpleGrey80  = Color(0xFFCCC2DC)
val Pink80        = Color(0xFFEFB8C8)

val Purple40      = Color(0xFF6650A4)
val PurpleGrey40  = Color(0xFF625B71)
val Pink40        = Color(0xFF7D5260)
EOF

  # Type.kt
  cat > "${src}/ui/theme/Type.kt" << EOF
package ${PKG_NAME}.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

val Typography = Typography(
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize   = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.5.sp
    )
)
EOF

  # Test files
  cat > "${PROJECT_DIR}/app/src/test/kotlin/${PKG_PATH}/ExampleUnitTest.kt" << EOF
package ${PKG_NAME}

import org.junit.Assert.assertEquals
import org.junit.Test

class ExampleUnitTest {
    @Test
    fun addition_isCorrect() {
        assertEquals(4, 2 + 2)
    }
}
EOF

  cat > "${PROJECT_DIR}/app/src/androidTest/kotlin/${PKG_PATH}/ExampleInstrumentedTest.kt" << EOF
package ${PKG_NAME}

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ExampleInstrumentedTest {
    @Test
    fun useAppContext() {
        val appContext = InstrumentationRegistry.getInstrumentation().targetContext
        assertEquals("${PKG_NAME}", appContext.packageName)
    }
}
EOF

  success "Kotlin sources written"
}

# ─── Android resources ────────────────────────────────────────────────────────
write_resources() {
  step "Writing Android resources..."

  local res="${PROJECT_DIR}/app/src/main/res"

  # strings.xml
  cat > "${res}/values/strings.xml" << EOF
<resources>
    <string name="app_name">${APP_NAME_XML}</string>
    <string name="greeting">Hello, World! 👋</string>
</resources>
EOF

  # themes.xml
  cat > "${res}/values/themes.xml" << EOF
<resources>
    <style name="Theme.${APP_NAME_SAFE}" parent="android:Theme.Material.Light.NoActionBar" />
</resources>
EOF

  # colors.xml
  cat > "${res}/values/colors.xml" << EOF
<resources>
    <color name="ic_launcher_background">${ICON_BG_COLOR}</color>
</resources>
EOF

  # ic_launcher_background.xml — matches user-chosen background color
  cat > "${res}/drawable/ic_launcher_background.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="${ICON_BG_COLOR}" />
</shape>
EOF

  # NOTE: ic_launcher_foreground.png + ic_launcher_background.png are generated
  # as proper PNG layers in each mipmap-*dpi/ folder by generate_icons().
  # The mipmap-anydpi-v26/ XML wrappers are written by _write_adaptive_icon_xmls().

  # AndroidManifest.xml
  cat > "${PROJECT_DIR}/app/src/main/AndroidManifest.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.${APP_NAME_SAFE}"
        android:dataExtractionRules="@xml/data_extraction_rules"
        android:fullBackupContent="@xml/backup_rules">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:label="@string/app_name"
            android:theme="@style/Theme.${APP_NAME_SAFE}">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

    </application>

</manifest>
EOF

  # backup_rules.xml
  mkdir -p "${res}/xml"
  cat > "${res}/xml/backup_rules.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
    <!--
      See developer.android.com/guide/topics/data/autobackup
      for documentation.
    -->
</full-backup-content>
EOF

  cat > "${res}/xml/data_extraction_rules.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup>
        <!-- TODO: Use <include> and <exclude> to control what is backed up. -->
    </cloud-backup>
</data-extraction-rules>
EOF

  # proguard-rules.pro
  cat > "${PROJECT_DIR}/app/proguard-rules.pro" << 'EOF'
# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in the Android SDK's default ProGuard rules.

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Keep Compose
-keep class androidx.compose.** { *; }

# Keep app entry points
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
EOF

  success "Resources written"
}

# ─── Icon generation ──────────────────────────────────────────────────────────
generate_icons() {
  step "Generating launcher icons..."

  local res="${PROJECT_DIR}/app/src/main/res"

  # ── Pixel sizes for each density ─────────────────────────────────────────
  # Legacy launcher PNGs  (mipmap-*dpi/ic_launcher.png & ic_launcher_round.png)
  declare -A LEGACY_SIZES=(
    [mdpi]=48
    [hdpi]=72
    [xhdpi]=96
    [xxhdpi]=144
    [xxxhdpi]=192
  )

  # Adaptive icon layer PNGs  (mipmap-*dpi/ic_launcher_foreground.png & ic_launcher_background.png)
  # Full 108dp canvas at each density: mdpi=108, hdpi=162, xhdpi=216, xxhdpi=324, xxxhdpi=432
  declare -A ADAPTIVE_SIZES=(
    [mdpi]=108
    [hdpi]=162
    [xhdpi]=216
    [xxhdpi]=324
    [xxxhdpi]=432
  )

  if [ "$HAS_IMAGEMAGICK" = false ]; then
    # ── No ImageMagick: embed minimal 1-px PNGs so the build doesn't fail ──
    warn "ImageMagick not available. Writing minimal placeholder PNGs (build will succeed)."
    warn "Install ImageMagick and re-run to get proper icons: sudo apt install imagemagick"
    # 1×1 purple pixel (valid PNG, base64)
    local TINY_PNG='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
    # 1×1 white pixel (for background layer)
    local TINY_WHITE='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIABQAABjE+ibYAAAAASUVORK5CYII='
    for DENSITY in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
      mkdir -p "${res}/mipmap-${DENSITY}"
      echo "$TINY_PNG"   | base64 -d > "${res}/mipmap-${DENSITY}/ic_launcher.png"
      echo "$TINY_PNG"   | base64 -d > "${res}/mipmap-${DENSITY}/ic_launcher_round.png"
      echo "$TINY_PNG"   | base64 -d > "${res}/mipmap-${DENSITY}/ic_launcher_foreground.png"
      echo "$TINY_WHITE" | base64 -d > "${res}/mipmap-${DENSITY}/ic_launcher_background.png"
    done
    return
  fi

  # ── Prepare source image ──────────────────────────────────────────────────
  local SOURCE_IMG=""

  if [ -n "$LOGO_PATH" ]; then
    SOURCE_IMG="$LOGO_PATH"
    success "Using provided logo: $SOURCE_IMG"
  else
    # Generate a Material-style placeholder: gradient bg + first letter centred
    local PLACEHOLDER="/tmp/icon_src_$$.png"
    convert -size 1024x1024 \
      gradient:'#6650A4-#9C82E0' \
      -gravity Center \
      -font DejaVu-Sans-Bold \
      -pointsize 520 \
      -fill white \
      -annotate 0 "${APP_NAME:0:1}" \
      "$PLACEHOLDER" 2>/dev/null \
    || convert -size 1024x1024 xc:'#6650A4' \
         -fill white \
         -draw "circle 512,512 512,250" \
         "$PLACEHOLDER" 2>/dev/null \
    || { warn "Placeholder generation failed — skipping icon generation."; return; }
    SOURCE_IMG="$PLACEHOLDER"
    info "Generated placeholder icon (first-letter Material style)"
  fi

  # ── Build adaptive foreground layer (108dp canvas, logo in safe zone) ────
  # Safe zone = inner 72dp of 108dp canvas = 66.7 % of total size
  # At xxxhdpi: canvas=432px, safe zone=288px, padding=(432-288)/2=72px each side
  # We resize the logo to fit within the safe zone, then pad to full canvas size.
  local FG_SRC="/tmp/icon_fg_$$.png"
  # Convert to RGBA so it supports transparency
  convert "$SOURCE_IMG" -alpha set -background none \
    -resize '288x288>' \
    -gravity center \
    -extent 432x432 \
    "$FG_SRC" 2>/dev/null \
  || convert "$SOURCE_IMG" \
    -resize '288x288>' \
    -gravity center \
    -background none \
    -extent 432x432 \
    "$FG_SRC" 2>/dev/null \
  || cp "$SOURCE_IMG" "$FG_SRC"

  # ── Generate all density sets ─────────────────────────────────────────────
  for DENSITY in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    local LEG_SIZE="${LEGACY_SIZES[$DENSITY]}"
    local ADP_SIZE="${ADAPTIVE_SIZES[$DENSITY]}"
    local OUT="${res}/mipmap-${DENSITY}"
    mkdir -p "$OUT"

    # ── 1. Legacy square icon ───────────────────────────────────────────────
    # bg color + logo scaled to fill icon fully
    convert \
      \( -size "${LEG_SIZE}x${LEG_SIZE}" xc:"${ICON_BG_COLOR}" \) \
      \( "$SOURCE_IMG" -resize "${LEG_SIZE}x${LEG_SIZE}!" \) \
      -gravity center -composite \
      "${OUT}/ic_launcher.png" 2>/dev/null \
    && success "  ${DENSITY} legacy ${LEG_SIZE}×${LEG_SIZE} → ic_launcher.png" \
    || warn "  ${DENSITY}: ic_launcher.png failed"

    # ── 2. Legacy round icon ────────────────────────────────────────────────
    # bg color + logo, then circle-masked
    convert \
      \( -size "${LEG_SIZE}x${LEG_SIZE}" xc:"${ICON_BG_COLOR}" \) \
      \( "$SOURCE_IMG" -resize "${LEG_SIZE}x${LEG_SIZE}!" \) \
      -gravity center -composite \
      \( +clone -alpha extract \
         -draw "fill white circle $(( LEG_SIZE/2 )),$(( LEG_SIZE/2 )) $(( LEG_SIZE/2 )),1" \
         -alpha shape \) \
      -compose DstIn -composite \
      "${OUT}/ic_launcher_round.png" 2>/dev/null \
    && success "  ${DENSITY} legacy ${LEG_SIZE}×${LEG_SIZE} → ic_launcher_round.png" \
    || { cp "${OUT}/ic_launcher.png" "${OUT}/ic_launcher_round.png" 2>/dev/null
         warn "  ${DENSITY}: circle-crop failed, using square as round fallback"; }

    # ── 3. Adaptive foreground layer ────────────────────────────────────────
    # Logo on transparent canvas, sized to safe zone (66% of full canvas)
    # Safe zone ensures logo isn't clipped by circle/squircle launcher masks
    local safe_adp=$(( ADP_SIZE * 2 / 3 ))
    convert \
      -size "${ADP_SIZE}x${ADP_SIZE}" xc:none \
      \( "$SOURCE_IMG" -resize "${safe_adp}x${safe_adp}" \) \
      -gravity center -composite \
      "${OUT}/ic_launcher_foreground.png" 2>/dev/null \
    && success "  ${DENSITY} adaptive ${ADP_SIZE}×${ADP_SIZE} → ic_launcher_foreground.png" \
    || warn "  ${DENSITY}: ic_launcher_foreground.png failed"

    # ── 4. Adaptive background layer ────────────────────────────────────────
    # Opaque bg color — never transparent (causes empty circle on MIUI/some launchers)
    convert -size "${ADP_SIZE}x${ADP_SIZE}" xc:"${ICON_BG_COLOR}" \
      "${OUT}/ic_launcher_background.png" 2>/dev/null \
    && success "  ${DENSITY} adaptive ${ADP_SIZE}×${ADP_SIZE} → ic_launcher_background.png" \
    || warn "  ${DENSITY}: ic_launcher_background.png failed"

  done

  # ── Play Store high-res icon (512×512) ───────────────────────────────────
  # White background required by Play Store (no transparency allowed)
  local STORE_DIR="${PROJECT_DIR}/fastlane/metadata/android/en-US/images"
  mkdir -p "$STORE_DIR"
  convert \
    \( -size 512x512 xc:"${ICON_BG_COLOR}" \) \
    \( "$SOURCE_IMG" -resize '512x512!' \) \
    -gravity center -composite \
    "${STORE_DIR}/icon.png" 2>/dev/null \
  && success "Play Store icon 512×512 → fastlane/metadata/.../icon.png" \
  || warn "Play Store icon generation failed"

  # ── Clean up temp files ───────────────────────────────────────────────────
  rm -f "/tmp/icon_src_$$.png" "/tmp/icon_fg_$$.png" "/tmp/icon_bg_$$.png"

  success "All icons generated"
}

# ─── Update adaptive icon XMLs to reference mipmap layers ────────────────────
# Called AFTER generate_icons so we can use @mipmap refs (PNG layers exist)
_write_adaptive_icon_xmls() {
  local res="${PROJECT_DIR}/app/src/main/res"
  mkdir -p "${res}/mipmap-anydpi-v26"

  cat > "${res}/mipmap-anydpi-v26/ic_launcher.xml" << 'ADAPTIVEEOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
ADAPTIVEEOF

  cat > "${res}/mipmap-anydpi-v26/ic_launcher_round.xml" << 'ADAPTIVEEOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
ADAPTIVEEOF

  success "Adaptive icon XMLs written (mipmap-anydpi-v26)"
}

# ─── GitHub Actions workflow ──────────────────────────────────────────────────
write_github_workflow() {
  step "Writing GitHub Actions CI/CD workflow..."

  cat > "${PROJECT_DIR}/.github/workflows/android-ci.yml" << EOF
name: Android CI/CD

on:
  push:
    branches: [ main, develop ]
    tags:
      - 'v*'
  pull_request:
    branches: [ main, develop ]
  workflow_dispatch:

concurrency:
  group: \${{ github.workflow }}-\${{ github.ref }}
  cancel-in-progress: true

env:
  JAVA_VERSION: '${JAVA_VERSION}'
  GRADLE_OPTS: '-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=2'

jobs:
  # ── Lint & Unit Tests ─────────────────────────────────────────────────────
  test:
    name: Lint & Unit Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up JDK \${{ env.JAVA_VERSION }}
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: \${{ env.JAVA_VERSION }}
          cache: gradle

      - name: Grant execute permission for gradlew
        run: chmod +x gradlew

      - name: Run lint
        run: ./gradlew lint --no-daemon

      - name: Run unit tests
        run: ./gradlew test --no-daemon

      - name: Upload lint results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: lint-results
          path: app/build/reports/lint-results-*.html
          retention-days: 7

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: app/build/reports/tests/
          retention-days: 7

  # ── Debug Build ───────────────────────────────────────────────────────────
  build-debug:
    name: Build Debug APK
    runs-on: ubuntu-latest
    needs: test
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK \${{ env.JAVA_VERSION }}
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: \${{ env.JAVA_VERSION }}
          cache: gradle

      - name: Grant execute permission for gradlew
        run: chmod +x gradlew

      - name: Build debug APK
        run: ./gradlew assembleDebug --no-daemon

      - name: Upload debug APK
        uses: actions/upload-artifact@v4
        with:
          name: debug-apk
          path: app/build/outputs/apk/debug/*.apk
          retention-days: 7

  # ── Release Build (on tag) ────────────────────────────────────────────────
  build-release:
    name: Build Release APK & AAB
    runs-on: ubuntu-latest
    needs: test
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK \${{ env.JAVA_VERSION }}
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: \${{ env.JAVA_VERSION }}
          cache: gradle

      - name: Grant execute permission for gradlew
        run: chmod +x gradlew

      - name: Decode keystore
        env:
          KEYSTORE_BASE64: \${{ secrets.KEYSTORE_BASE64 }}
        run: |
          if [ -n "\$KEYSTORE_BASE64" ]; then
            echo "\$KEYSTORE_BASE64" | base64 -d > app/release.keystore
            echo "KEYSTORE_AVAILABLE=true" >> \$GITHUB_ENV
          else
            echo "KEYSTORE_AVAILABLE=false" >> \$GITHUB_ENV
            echo "⚠ No keystore secret set — building unsigned release"
          fi

      - name: Build release APK
        env:
          KEYSTORE_PASSWORD: \${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS:         \${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD:      \${{ secrets.KEY_PASSWORD }}
        run: ./gradlew assembleRelease --no-daemon

      - name: Build release AAB
        env:
          KEYSTORE_PASSWORD: \${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS:         \${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD:      \${{ secrets.KEY_PASSWORD }}
        run: ./gradlew bundleRelease --no-daemon

      - name: Upload release APK
        uses: actions/upload-artifact@v4
        with:
          name: release-apk
          path: app/build/outputs/apk/release/*.apk

      - name: Upload release AAB
        uses: actions/upload-artifact@v4
        with:
          name: release-aab
          path: app/build/outputs/bundle/release/*.aab

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            app/build/outputs/apk/release/*.apk
            app/build/outputs/bundle/release/*.aab
          generate_release_notes: true
        env:
          GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}
EOF

  success "GitHub Actions workflow written"
}

# ─── GitLab CI ───────────────────────────────────────────────────────────────
write_gitlab_ci() {
  step "Writing GitLab CI/CD pipeline..."

  cat > "${PROJECT_DIR}/.gitlab-ci.yml" << EOF
# ── ${APP_NAME} · GitLab CI/CD ────────────────────────────────────────────────
image: eclipse-temurin:${JAVA_VERSION}-jdk

stages:
  - validate
  - test
  - build
  - release

variables:
  GRADLE_OPTS: "-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=2 -Dorg.gradle.caching=true"
  ANDROID_SDK_ROOT: "\${CI_PROJECT_DIR}/android-sdk"
  ANDROID_HOME:     "\${CI_PROJECT_DIR}/android-sdk"

# ── Cache ─────────────────────────────────────────────────────────────────────
.gradle-cache: &gradle-cache
  cache:
    key:
      files:
        - gradle/wrapper/gradle-wrapper.properties
        - gradle/libs.versions.toml
    paths:
      - .gradle/wrapper/
      - .gradle/caches/
      - android-sdk/
    policy: pull-push

# ── Android SDK install ───────────────────────────────────────────────────────
.setup-sdk: &setup-sdk
  before_script:
    - apt-get update -qq && apt-get install -y -qq wget unzip python3 2>/dev/null
    - |
      if [ ! -d "\$ANDROID_SDK_ROOT/cmdline-tools" ]; then
        echo "Installing Android SDK..."
        mkdir -p "\$ANDROID_SDK_ROOT/cmdline-tools"
        wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdtools.zip
        unzip -q /tmp/cmdtools.zip -d /tmp/cmdtools_extracted
        mv /tmp/cmdtools_extracted/cmdline-tools "\$ANDROID_SDK_ROOT/cmdline-tools/latest"
        rm -f /tmp/cmdtools.zip
      fi
    - export PATH="\$PATH:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools"
    - yes | sdkmanager --licenses > /dev/null 2>&1 || true
    - sdkmanager "platforms;android-${TARGET_SDK}" "build-tools;${TARGET_SDK}.0.0" > /dev/null 2>&1 || true
    - chmod +x gradlew

# ── Lint ──────────────────────────────────────────────────────────────────────
lint:
  stage: validate
  <<: *gradle-cache
  <<: *setup-sdk
  script:
    - ./gradlew lint --no-daemon
  artifacts:
    when: always
    paths:
      - app/build/reports/lint-results-*.html
    expire_in: 1 week
  rules:
    - if: \$CI_PIPELINE_SOURCE == "merge_request_event"
    - if: \$CI_COMMIT_BRANCH

# ── Unit Tests ────────────────────────────────────────────────────────────────
unit-test:
  stage: test
  <<: *gradle-cache
  <<: *setup-sdk
  script:
    - ./gradlew test --no-daemon
  artifacts:
    when: always
    reports:
      junit: app/build/test-results/**/*.xml
    paths:
      - app/build/reports/tests/
    expire_in: 1 week
  rules:
    - if: \$CI_PIPELINE_SOURCE == "merge_request_event"
    - if: \$CI_COMMIT_BRANCH

# ── Debug Build ───────────────────────────────────────────────────────────────
build-debug:
  stage: build
  <<: *gradle-cache
  <<: *setup-sdk
  script:
    - ./gradlew assembleDebug --no-daemon
  artifacts:
    paths:
      - app/build/outputs/apk/debug/*.apk
    expire_in: 1 week
  rules:
    - if: \$CI_COMMIT_BRANCH == "main"
    - if: \$CI_COMMIT_BRANCH == "develop"
    - if: \$CI_PIPELINE_SOURCE == "merge_request_event"

# ── Release Build (on tag) ────────────────────────────────────────────────────
build-release:
  stage: build
  <<: *gradle-cache
  <<: *setup-sdk
  script:
    - |
      if [ -n "\$KEYSTORE_BASE64" ]; then
        echo "\$KEYSTORE_BASE64" | base64 -d > app/release.keystore
      fi
    - ./gradlew assembleRelease bundleRelease --no-daemon
  artifacts:
    paths:
      - app/build/outputs/apk/release/*.apk
      - app/build/outputs/bundle/release/*.aab
    expire_in: 30 days
  rules:
    - if: \$CI_COMMIT_TAG =~ /^v.*/

# ── Create Release ────────────────────────────────────────────────────────────
gitlab-release:
  stage: release
  image: registry.gitlab.com/gitlab-org/release-cli:latest
  needs:
    - job: build-release
      artifacts: true
  script:
    - echo "Creating GitLab release for \$CI_COMMIT_TAG"
  release:
    name:        "Release \$CI_COMMIT_TAG"
    description: "Auto-generated release for \$CI_COMMIT_TAG"
    tag_name:    "\$CI_COMMIT_TAG"
    assets:
      links:
        - name: "APK (release)"
          url:  "\$CI_PROJECT_URL/-/jobs/\$CI_JOB_ID/artifacts/raw/app/build/outputs/apk/release/app-release.apk"
  rules:
    - if: \$CI_COMMIT_TAG =~ /^v.*/
EOF

  success "GitLab CI/CD pipeline written"
}

# ─── Root config files ────────────────────────────────────────────────────────
write_root_files() {
  step "Writing root config files..."

  # .gitignore
  cat > "${PROJECT_DIR}/.gitignore" << 'EOF'
# Android
*.apk
*.aar
*.ap_
*.aab

# Build outputs
build/
.build/
app/build/

# Gradle
.gradle/
gradle-app.setting
!gradle-wrapper.jar
!gradle-wrapper.properties
local.properties

# IDE
*.iml
.idea/
.idea/workspace.xml
.idea/tasks.xml
.idea/gradle.xml
.idea/assetWizardSettings.xml
.idea/dictionaries
.idea/libraries
.idea/caches
.DS_Store

# Keys — never commit!
*.keystore
*.jks
release.keystore

# Fastlane
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots
fastlane/test_output

# OS
Thumbs.db
*.swp
EOF

  # README.md
  cat > "${PROJECT_DIR}/README.md" << EOF
# ${APP_NAME}

> A modern Android application built with Kotlin + Jetpack Compose.

[![Android CI/CD](https://github.com/MaheshTechnicals/android-project-generator/actions/workflows/android-ci.yml/badge.svg)](https://github.com/MaheshTechnicals/android-project-generator/actions)

## Tech Stack

| Component             | Version            |
|-----------------------|--------------------|
| Kotlin                | ${KOTLIN_VERSION}  |
| Android Gradle Plugin | ${AGP_VERSION}     |
| Gradle                | ${GRADLE_VERSION}  |
| Target SDK            | ${TARGET_SDK}      |
| Min SDK               | ${MIN_SDK}         |
| Jetpack Compose       | BOM ${COMPOSE_BOM_VERSION} |

## Getting Started

\`\`\`bash
# Clone
git clone <your-repo-url>
cd ${DEFAULT_DIR}

# Build debug APK
./gradlew assembleDebug

# Run unit tests
./gradlew test

# APK location
# app/build/outputs/apk/debug/app-debug.apk
\`\`\`

## CI/CD

- **GitHub Actions** — lint, unit tests, debug/release builds on push. Release APK + AAB uploaded on tag push (\`v*\`).
- **GitLab CI** — same pipeline with integrated GitLab Releases.

## Release

Push a tag to trigger a release build:

\`\`\`bash
git tag v1.0.0
git push origin v1.0.0
\`\`\`

### Required Secrets (for signed release builds)

| Secret              | Description                     |
|---------------------|---------------------------------|
| \`KEYSTORE_BASE64\`   | Base64-encoded keystore file    |
| \`KEYSTORE_PASSWORD\` | Keystore password               |
| \`KEY_ALIAS\`         | Key alias                       |
| \`KEY_PASSWORD\`      | Key password                    |

## Package

\`${PKG_NAME}\`

---
*Scaffolded with [Android Project Generator](https://github.com/MaheshTechnicals/android-project-generator) by Mahesh Technicals*
EOF

  # local.properties template (not committed)
  cat > "${PROJECT_DIR}/local.properties.template" << EOF
# Copy to local.properties and fill in your SDK path
sdk.dir=/home/\$USER/Android/Sdk
# or on macOS: /Users/\$USER/Library/Android/sdk
EOF

  # gradle.properties
  cat > "${PROJECT_DIR}/gradle.properties" << EOF
# Project-wide Gradle settings
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8 -XX:+UseG1GC
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configuration-cache=true

# Android
android.useAndroidX=true
android.nonTransitiveRClass=true
android.suppressUnsupportedOptionWarnings=true

# Kotlin
kotlin.code.style=official
kotlin.incremental=true
EOF

  success "Root files written"
}

# ─── Git initialization ───────────────────────────────────────────────────────
init_git() {
  step "Initializing Git repository..."

  if ! check_cmd git; then
    warn "git not found — skipping git init"
    return
  fi

  cd "$PROJECT_DIR"
  git init -b main
  git add .
  git commit -m "🎉 Initial commit — scaffolded by create-android-app.sh

App     : ${APP_NAME}
Package : ${PKG_NAME}
AGP     : ${AGP_VERSION}
Kotlin  : ${KOTLIN_VERSION}
Gradle  : ${GRADLE_VERSION}

Generated by Android Project Generator — github.com/MaheshTechnicals/android-project-generator"

  if [ -n "${GIT_REMOTE:-}" ]; then
    git remote add origin "$GIT_REMOTE"
    success "Remote added: $GIT_REMOTE"
    info "Push with: git push -u origin main"
  fi

  cd - > /dev/null
  success "Git repository initialized"
}

# ─── Final instructions ───────────────────────────────────────────────────────
print_final() {
  local ABS_DIR
  ABS_DIR=$(realpath "$PROJECT_DIR")

  echo ""
  echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${GREEN}  ✅  Project Ready!${RESET}"
  echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
  echo -e "  ${BOLD}Location:${RESET}  $ABS_DIR"
  echo ""
  echo -e "  ${BOLD}Next steps:${RESET}"
  echo -e "  ${CYAN}cd ${PROJECT_DIR}${RESET}"
  echo ""
  echo -e "  ${BOLD}Build debug APK:${RESET}"
  echo -e "  ${CYAN}./gradlew assembleDebug${RESET}"
  echo -e "  ${YELLOW}  → app/build/outputs/apk/debug/app-debug.apk${RESET}"
  echo ""
  echo -e "  ${BOLD}Build release APK:${RESET}"
  echo -e "  ${CYAN}./gradlew assembleRelease${RESET}"
  echo ""
  echo -e "  ${BOLD}Build AAB (Play Store):${RESET}"
  echo -e "  ${CYAN}./gradlew bundleRelease${RESET}"
  echo ""
  echo -e "  ${BOLD}Run unit tests:${RESET}"
  echo -e "  ${CYAN}./gradlew test${RESET}"
  echo ""
  echo -e "  ${BOLD}Open in Android Studio:${RESET}"
  echo -e "  ${CYAN}File → Open → $ABS_DIR${RESET}"
  echo ""
  if [ "$HAS_IMAGEMAGICK" = false ]; then
    echo -e "  ${YELLOW}⚠  Install ImageMagick for better icons:${RESET}"
    echo -e "  ${CYAN}sudo apt install imagemagick${RESET}"
    echo ""
  fi
  echo -e "  ${BOLD}Versions used:${RESET}"
  echo -e "  AGP ${AGP_VERSION}  ·  Kotlin ${KOTLIN_VERSION}  ·  Gradle ${GRADLE_VERSION}"
  echo -e "  Compose BOM ${COMPOSE_BOM_VERSION}  ·  Target SDK ${TARGET_SDK}"
  echo ""
  echo -e "${MAGENTA}  Made with ♥ by Mahesh Technicals${RESET}"
  echo -e "${MAGENTA}  github.com/MaheshTechnicals/android-project-generator${RESET}"
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  print_banner
  fetch_latest_versions
  check_dependencies
  collect_input
  derive_vars
  create_structure
  write_gradle_files
  write_kotlin_sources
  write_resources
  generate_icons
  _write_adaptive_icon_xmls
  write_github_workflow
  write_gitlab_ci
  write_root_files
  init_git
  print_final
}

main "$@"
