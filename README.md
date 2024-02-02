# Everest

A mathematical puzzle game. Try it at https://mwageringel.github.io/everest/

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png"
     alt="Get it on F-Droid"
     height="80">](https://f-droid.org/packages/io.github.mwageringel.everest/)

## Build dependencies

Building with `make` requires `curl, rsvg-convert, imagemagick, java 17+` and optionally `flutter`.

Either use the pinned version of Flutter (`./vendor/flutter/bin/flutter`):

    git submodule update --init --recursive
    make

Or use the Flutter version installed on your system:

    make FLUTTER=flutter

(If you use Android Studio, make sure that `flutter.sdk` and the Android `sdk.dir`
are set correctly in the untracked file `./android/local.properties`.)


APK signing certificate fingerprint (SHA-256) of releases on GitHub:

    576bae61b2aba5d1d32a17d373baa36e05beaaefb67d9b47218d004c0e8333d9

## Available Languages

- English
- French
- German
- Italian
- Spanish
- Ukrainian

Thanks to all the contributors.
Additional translations are welcome – these are the files to translate:
- [metadata/en-US/full_description.txt](metadata/en-US/full_description.txt)
- [metadata/en-US/short_description.txt](metadata/en-US/short_description.txt)
- [lib/l10n/app_en.arb](lib/l10n/app_en.arb)
