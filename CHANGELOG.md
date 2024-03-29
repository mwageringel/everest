# Changelog

## [Unreleased]

## [1.1.6] - 2024-02-04
### Added
- Italian translation (by @gabriblas)
- the web version now saves the progress (works on iOS, as well) (#26)

### Changed
- upgraded to Flutter 3.16.9; the Flutter version is now pinned in a submodule

### Fixed
- a UI issue affecting the html renderer of mobile browsers in which the focussed question was vertically displaced
- a UI issue in which the scroll animation could be triggered incorrectly
- an issue that could affect mobile browsers without WebAssembly support
- a rendering issue affecting LineageOS (#17)

## [1.1.5] - 2022-09-19
### Added
- French translation (by @DodoLeDev)
- several tests

### Changed
- sets of questions now show an icon for each question for better visual feedback

## [1.1.4] - 2022-09-01
### Added
- Ukrainian translation (by @andmizyk)
- Spanish translation (by @thermosflasche)

## [1.1.3] - 2022-08-15
### Added
- German translation and support for translations to other languages (implemented by @vrifox)

### Changed
- small revision of the first few levels
- small changes to navigation to give more priority to the subpages, especially in the first levels

### Fixed
- an issue in which level 1 did not unlock
  (Workaround for version 1.1.2: Solve the very first question again or change the theme.)
- a display issue with enlarged system fonts
- the website URL is now clickable

## [1.1.2] - 2022-07-22
### Added
- a new first level
- a new icon

## [1.1.1] - 2022-07-20
### Added
- automatic scrolling to the next question
- support for keyboard input

### Changed
- improved rendering performance

## [1.1.0] - 2022-07-16
### Added
- website

### Changed
- appearance and color scheme

[Unreleased]: https://github.com/mwageringel/everest/compare/1.1.6...HEAD
[1.1.6]: https://github.com/mwageringel/everest/compare/1.1.5...1.1.6
[1.1.5]: https://github.com/mwageringel/everest/compare/1.1.4...1.1.5
[1.1.4]: https://github.com/mwageringel/everest/compare/1.1.3...1.1.4
[1.1.3]: https://github.com/mwageringel/everest/compare/1.1.2...1.1.3
[1.1.2]: https://github.com/mwageringel/everest/compare/1.1.1...1.1.2
[1.1.1]: https://github.com/mwageringel/everest/compare/1.1.0...1.1.1
[1.1.0]: https://github.com/mwageringel/everest/releases/tag/1.1.0
