FLUTTER=flutter
BASEHREF=/demo/

all: app web
app: assets-android
	$(FLUTTER) config --no-analytics
	$(FLUTTER) build apk
web: assets-web
	$(FLUTTER) build web --base-href=$(BASEHREF) --release
	rm -rf website/demo/
	cp -p -r build/web/ website/demo/
gh-pages:
	$(FLUTTER) clean
	$(MAKE) BASEHREF=/everest/demo/ web
	# assumes worktree gh-pages is checked out in ./gh-pages/
	cd gh-pages && git rm -rf . --ignore-unmatch && cp -p -r ../website/* . && git add . && git commit --amend --no-edit
host:
	cd website && python -m http.server 8000
run: assets-android assets-web
	$(FLUTTER) run
test:
	$(FLUTTER) test test/expressions_test.dart
clean: icons-clean
	$(FLUTTER) clean
	rm -rf website/demo/

assets-android: fonts icons-android
assets-web: fonts icons-web

# rasterized icons are generated from an svg file
icons-android: android/app/src/main/res/mipmap-hdpi/ic_launcher.png
assets/launcher_icon.png: assets/launcher_icon.svg
	rsvg-convert --width=1024 --height=1024 --keep-aspect-ratio assets/launcher_icon.svg > $@
assets/launcher_icon_adaptive.png: assets/launcher_icon_adaptive.svg
	rsvg-convert --page-width=1024 --page-height=1024 --width=584 --height=584 --top=220 --left=220 --keep-aspect-ratio assets/launcher_icon_adaptive.svg > $@
android/app/src/main/res/mipmap-hdpi/ic_launcher.png: assets/launcher_icon.png assets/launcher_icon_adaptive.png
	$(FLUTTER) pub get
	$(FLUTTER) pub run flutter_launcher_icons:main

icons-web: website/favicon.ico web/favicon.ico web/icons/Icon-192.png web/icons/Icon-maskable-192.png web/icons/Icon-512.png web/icons/Icon-maskable-512.png
web/favicon.ico website/favicon.ico: assets/launcher_icon.svg
	magick -background none assets/launcher_icon.svg -define icon:auto-resize $@
web/icons/Icon-192.png: assets/launcher_icon.svg
	mkdir -p web/icons/
	rsvg-convert --width=192 --height=192 --keep-aspect-ratio assets/launcher_icon.svg > $@
web/icons/Icon-512.png: assets/launcher_icon.svg
	mkdir -p web/icons/
	rsvg-convert --width=512 --height=512 --keep-aspect-ratio assets/launcher_icon.svg > $@
web/icons/Icon-maskable-192.png: assets/launcher_icon_adaptive.svg
	mkdir -p web/icons/
	rsvg-convert --page-width=192 --page-height=192 --width=150 --height=150 --top=21 --left=21 --keep-aspect-ratio -b '#536dfeff' assets/launcher_icon_adaptive.svg > $@
web/icons/Icon-maskable-512.png: assets/launcher_icon_adaptive.svg
	mkdir -p web/icons/
	rsvg-convert --page-width=512 --page-height=512 --width=400 --height=400 --top=56 --left=56 --keep-aspect-ratio -b '#536dfeff' assets/launcher_icon_adaptive.svg > $@
icons-clean:
	rm -f android/app/src/main/res/mipmap-*/ic_launcher.png
	rm -f website/favicon.ico web/favicon.ico web/icons/*.png
	rm -f assets/launcher_icon.png assets/launcher_icon_adaptive.png

# fonts are downloaded and bundled into the app
fonts: fonts/NotoSansMath-Regular.ttf
fonts/NotoSansMath-Regular.ttf: | build/upstream/Noto_Sans_Math.zip
	mkdir -p fonts/
	unzip -o build/upstream/Noto_Sans_Math.zip -d fonts/
build/upstream/Noto_Sans_Math.zip:
	mkdir -p build/upstream/
	curl --output build/upstream/Noto_Sans_Math.zip https://fonts.google.com/download?family=Noto%20Sans%20Math
.INTERMEDIATE: build/upstream/Noto_Sans_Math.zip

.PHONY: all app web gh-pages host run test assets-android assets-web fonts icons-android icons-web icons-clean clean
