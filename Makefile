all: app web
app: fonts icons
	flutter build apk
BASEHREF=/demo/
web: fonts icons
	flutter build web --base-href=$(BASEHREF) --release
	rm -rf website/demo/
	cp -p -r build/web/ website/demo/
gh-pages:
	flutter clean
	make BASEHREF=/everest/demo/ web
	# assumes worktree gh-pages is checked out in ./gh-pages/
	cd gh-pages && git rm -rf . --ignore-unmatch && cp -p -r ../website/* . && git add . && git commit -m "update gh-pages"
host:
	cd website && python -m http.server 8000
run: fonts icons
	flutter run
test:
	flutter test test/expressions_test.dart
clean: icons-clean
	flutter clean
	rm -rf website/demo/

icons: android/app/src/main/res/mipmap-hdpi/ic_launcher.png website/favicon.ico web/favicon.ico web/icons/Icon-192.png web/icons/Icon-maskable-192.png web/icons/Icon-512.png web/icons/Icon-maskable-512.png
android/app/src/main/res/mipmap-hdpi/ic_launcher.png: assets/launcher_icon.png
	flutter pub get
	flutter pub run flutter_launcher_icons:main
assets/launcher_icon.png: assets/launcher_icon.svg
	inkscape -w 1024 -h 1024 assets/launcher_icon.svg -o assets/launcher_icon.png
web/favicon.ico website/favicon.ico: assets/launcher_icon.svg
	magick -background none assets/launcher_icon.svg -define icon:auto-resize $@
web/icons/Icon-192.png web/icons/Icon-maskable-192.png: assets/launcher_icon.svg
	mkdir -p web/icons/
	inkscape -w 192 -h 192 assets/launcher_icon.svg -o $@
web/icons/Icon-512.png web/icons/Icon-maskable-512.png: assets/launcher_icon.svg
	mkdir -p web/icons/
	inkscape -w 512 -h 512 assets/launcher_icon.svg -o $@
icons-clean:
	rm -f android/app/src/main/res/mipmap-*/ic_launcher.png
	rm -f website/favicon.ico web/favicon.ico web/icons/*.png
	rm -f assets/launcher_icon.png

fonts: fonts/NotoSansMath-Regular.ttf
fonts/NotoSansMath-Regular.ttf: | build/upstream/Noto_Sans_Math.zip
	mkdir -p fonts/
	unzip -o build/upstream/Noto_Sans_Math.zip -d fonts/
build/upstream/Noto_Sans_Math.zip:
	mkdir -p build/upstream/
	wget -O build/upstream/Noto_Sans_Math.zip https://fonts.google.com/download?family=Noto%20Sans%20Math
.INTERMEDIATE: build/upstream/Noto_Sans_Math.zip

.PHONY: all app web gh-pages host run test zip fonts icons icons-clean clean
