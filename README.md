# FrostGuard

FrostGuard is an Android app built with Kotlin and Jetpack Compose. Open the `android` directory in Android Studio to build and run it. The Shizuku manager service must be running on the device for app control and RAM cleaning.

## Features

- Browse installed and system apps, search by app or package name, and freeze or unfreeze apps through Shizuku.
- Freeze or unfreeze all apps in the selected app category, and force-stop running apps.
- View live CPU, RAM, battery, GPU, temperature, and network readings. CPU, GPU, battery, and thermal detail screens show device-specific data when Android exposes it.
- Clean background memory and trim package caches through Shizuku.
- Keep a rolling CPU usage history for the hardware detail screen.

The Android source is in `android/app/src/main`. The app uses Kotlin and Jetpack Compose; Flutter is not required to build it.
