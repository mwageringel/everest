import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:everest/game.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

const appName = 'Everest';
const String themeModeKey = 'settings:themeMode';
const String pureBlackKey = 'settings:pureBlack';

Icon questionsStatusIcon(BuildContext context, QuestionsStatus status) {
  final light = Theme.of(context).brightness == Brightness.light;
  switch (status) {
    case QuestionsStatus.partial: return Icon(Icons.circle_outlined, color: Theme.of(context).colorScheme.secondary.withOpacity(.75));
    case QuestionsStatus.correct: return Icon(Icons.check_circle, color: Color(light ? 0xff1ca23e : 0xff2fae49));
    case QuestionsStatus.wrong: return Icon(Icons.cancel, color: Color(light ? 0xffd51529 : 0xfff6313a));
  }
}

class DampedCurve extends Curve {
  // a linearly damped oscillation in reverse
  @override double transformInternal(double t) {
    return cos(16*(1-t))*t;
  }
}
final _dampedCurve = DampedCurve();

class RotateCurve extends Curve {
  @override double transformInternal(double t) => t < 0.5 ? 0 : -cos(t*pi);
}
final _rotateCurve = RotateCurve();

class StatusIcon extends StatefulWidget {
  final QuestionsStatus status;
  final bool animateStatusWrong;
  const StatusIcon(this.status, {required this.animateStatusWrong, Key? key}) : super(key: key);

  @override
  State<StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<StatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 70),
    reverseDuration: const Duration(milliseconds: 420),
    vsync: this,
  );
  late final Animation<Offset> _animation = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.225, 0.0),
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutSine,
    reverseCurve: _dampedCurve,
  ));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runAnimation() async {
    try {  // circumvents intermediate disposal of _controller
      _controller.reset();  // stops previous animation if still in progress
      await _controller.forward().orCancel;
      await _controller.reverse().orCancel;
    } on TickerCanceled { /* ignore */ }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.animateStatusWrong && widget.status == QuestionsStatus.wrong) {
      _runAnimation();
    }
    Widget icon = SlideTransition(
      position: _animation,
      child: questionsStatusIcon(context, widget.status),
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 330),
      transitionBuilder: (Widget child, Animation<double> animation) => VerticalScaleTransition(child, animation),
      switchInCurve: _rotateCurve,
      switchOutCurve: _rotateCurve,
      child: Container(
        key: ValueKey<QuestionsStatus>(widget.status),
        child: icon,
      ),
    );
  }
}

class VerticalScaleTransition extends StatefulWidget {
  final Widget child;
  final Animation<double> animation;
  const VerticalScaleTransition(this.child, this.animation, {Key? key}) : super(key: key);
  @override createState() => _VerticalScaleTransitionState();
}
class _VerticalScaleTransitionState extends State<VerticalScaleTransition> {
  double scaleY = 1;
  void _update() => setState(() => scaleY = widget.animation.value);
  @override Widget build(BuildContext context) => Transform.scale(scaleY: scaleY, child: widget.child);
  @override void initState() {
    super.initState();
    scaleY = widget.animation.value;  // may be 1.0 or 0.0 depending on whether this is initial creation or animated switch, avoids flickering
    widget.animation.addListener(_update);
  }
  @override void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.animation, widget.animation)) {
      oldWidget.animation.removeListener(_update);
      scaleY = widget.animation.value;
      widget.animation.addListener(_update);
    }
  }
  @override void dispose() {
    widget.animation.removeListener(_update);
    super.dispose();
  }
}

final _listTileRadius = BorderRadius.circular(20);
final _listTileRounded = RoundedRectangleBorder(borderRadius: _listTileRadius);

class QuestionsWidget extends StatelessWidget {
  final List<Question> questions;
  final bool isActive;
  final int focussedQuestion;
  final bool animateStatusWrong;
  final bool doScroll;
  final void Function(int) onTap;
  final Widget? trailing;
  const QuestionsWidget(this.questions,
    {required this.isActive, required this.focussedQuestion, required bool animateStatusWrong, required bool doScroll, required this.onTap, this.trailing, Key? key}):
    animateStatusWrong = animateStatusWrong && isActive, doScroll = doScroll && isActive, super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = jointStatus(questions);  // TODO cache this?
    final c = Column(
      children: Iterable.generate(questions.length).map<Widget>((i) {
        // the following is more direct than expr.str() and works since all variables appear exactly once from left to right
        final q = questions[i].inputs.fold<String>(questions[i].q, (q, s) => q.replaceFirst('?', s));
        Widget? t;
        if (isActive && i == focussedQuestion) {
          var j = q.indexOf('?');
          if (j == -1) {
            j = questions[i].q.indexOf('?'); // relies on all replacements being single characters
          }
          if (j != -1) {
            t = Text.rich(TextSpan(
              text: q.substring(0, j),
              style: _biggerFont,
              children: [
                // TextSpan(text: q.substring(j, j+1), style: TextStyle(backgroundColor: Theme.of(context).focusColor)),
                WidgetSpan( // with padding
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).focusColor,
                      borderRadius: const BorderRadius.all(Radius.circular(3.0)),
                    ),
                    child: Text(q.substring(j, j+1), style: _biggerFont),
                  ),
                ),
                TextSpan(text: q.substring(j+1)),
              ],
            ));
          }
        }
        t ??= Text(q, style: _biggerFont);
        return ListTile(
          title: t,
          trailing: (i == questions.length - 1) ? StatusIcon(status, animateStatusWrong: animateStatusWrong) : null,
          shape: _listTileRounded,
          onTap: () => onTap(i)
        );
      }).followedBy([if (trailing != null) trailing!]).toList(),
    );
    if (doScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // for details about scrolling see https://stackoverflow.com/q/49153087
        Scrollable.ensureVisible(context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: const Duration(milliseconds: 800),
        );
      });
    }
    // Here we are careful to keep the widget tree the same regardless of whether widget is active,
    // since otherwise the status switch animation does not show.
    return Container(
      decoration: ShapeDecoration(
        color: isActive ? Theme.of(context).highlightColor : null,  // makes hover work on non-selected tiles and background color in pure black mode
        shape: _listTileRounded,  // TODO for pure black, add (side: const BorderSide(color: ...)),
      ),
      child: c
    );
  }
}

class BouncingWidget extends StatefulWidget {
  final Widget child;
  const BouncingWidget(this.child, {Key? key}) : super(key: key);

  @override
  State<BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget>
    with SingleTickerProviderStateMixin {
  // see https://api.flutter.dev/flutter/widgets/SlideTransition-class.html
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 400),
    reverseDuration: const Duration(milliseconds: 800),
    vsync: this,
  );
  late final Animation<Offset> _offsetAnimation = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-1.0, 0.0),
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutBack,
    reverseCurve: Curves.bounceIn,
  ));

  // instead of a permanent long animation, we use a timer with a short animation to avoid permanent high cpu usage
  late final Timer _timer;
  _BouncingWidgetState() {
    // despite the `late`, defining the timer here in the constructor (in contrast
    // to initializing it at declaration) ensures that it is actually started
    _timer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      await _controller.forward();
      await _controller.reverse();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: widget.child,
    );
  }
}

Iterable<A> interleave<A>(Iterable<A> it, A separator) {
  return it.expand((a) => [separator, a]).skip(1);
}

const listPadding = EdgeInsets.all(8.0);
const _biggerFont = TextStyle(fontSize: 18.0);

class KeyboardButton extends StatelessWidget {
  static const _keyIcons = {
    'backspace': Icons.backspace,
  };
  final String label;
  const KeyboardButton(this.label, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<Game>(builder: (context, game, child) =>
      Padding(
        padding: const EdgeInsets.all(2),
        child: SizedBox(
          height: 44,
          width: 66,
          child: OutlinedButton(
            child: _keyIcons.containsKey(label) ? Icon(_keyIcons[label], size: 26) : Text(label, style: const TextStyle(fontSize: 20)),
            onPressed: () => game.keyPressed(label),
          ),
        ),
      ),
    );
  }
}

class Keyboard extends StatelessWidget {
  const Keyboard({Key? key}) : super(key: key);

  static const _keys = [
    ['1', '4', '7', 'X'],
    ['2', '5', '8', '0'],
    ['3', '6', '9', 'backspace'],
    // ['backspace'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container( // alternatively use Material(elevation..)
      decoration: BoxDecoration(
        color: Theme.of(context).bottomAppBarColor,
        boxShadow: [
          BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.4), blurRadius: 4.0, offset: const Offset(0.0, -0.75)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _keys.map((col) =>
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: col.map((s) => KeyboardButton(s)).toList(),
          )
        ).toList(),
      ),
    );
  }
}

// setting thickness/color as a workaround for invisible dividers in mobile web browser https://github.com/flutter/flutter/issues/46339
class MyDivider extends StatelessWidget {
  const MyDivider({Key? key}) : super(key: key);
  @override build(BuildContext context) => Divider(
    thickness: 0.5,
    color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
  );
}

class LevelScreen extends StatelessWidget {
  const LevelScreen({ Key? key }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final level = Provider.of<Level>(context);
    return ListView(
      padding: listPadding,
      children: interleave(
        level.exercise.fullQuestions().map((es) => Selector<Level, bool>(
          // selector ensures that questions widget is only rebuilt when isActive is set or changes
          selector: (context, level) => es[0].key <= level.exercise.activeIndex && es.last.key >= level.exercise.activeIndex,  // isActive
          shouldRebuild: (bool oldIsActive, bool isActive) => oldIsActive || isActive,
          builder: (context, isActive, child) {
            final game = Provider.of<Game>(context);  // changes often, so consuming it inside selector avoids triggering rebuilds
            return InkWell(
              child: QuestionsWidget(es.map((e) => e.value).toList(),
                isActive: isActive,
                focussedQuestion: level.exercise.activeIndex - es[0].key,  // TODO use level and game from different context?
                animateStatusWrong: game.doStatusAnimation(),
                doScroll: game.doScrollAnimation(),
                onTap: (j) => game.levelTapped(es[0].key + j, inExam: false),
              ),
            );
          },
        )),
        const MyDivider(),
      ).toList(),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({ Key? key }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle textStyle = theme.textTheme.bodyText2!;
    return ListView(
      padding: listPadding,
      children: [
        const ListTile(
          leading: Icon(Icons.settings_brightness),
          title: Text('Theme'),
        ),
        Consumer2<World, Game>(builder: (context, world, game, child) =>
          Column(
            children: [
              ...(ThemeMode.values.map((ThemeMode m) =>
                RadioListTile<ThemeMode>(
                  value: m,
                  groupValue: world.themeMode,
                  title: Text(m.name),
                  onChanged: (mode) async {
                    world.switchTheme(themeMode: m);
                    return game.storeKeyValue(themeModeKey, m.toString());
                  },
                ),
              )),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.darkThemeBlackBackground),
                subtitle: const Text("Mainly intended for OLED screens"),
                value: world.pureBlack,
                onChanged: (bool value) async {
                  world.switchTheme(pureBlack: value);
                  return game.storeKeyValue(pureBlackKey, value.toString());
                },
              ),
            ],
          ),
        ),
        const MyDivider(),
        Consumer2<World, Game>(builder: (context, world, game, child) =>
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restart'),
            subtitle: const Text('Long press to reset the progress.'),
            onLongPress: () async {
              await game.resetProgress();
              world.resetWorld();
            },
          ),
        ),
        const MyDivider(),
        AboutListTile(
          icon: const Icon(Icons.info_outline),
          applicationVersion: "Version ${Provider.of<World>(context).appInfo.version}",
          aboutBoxChildren: [
            SelectableText.rich(
              TextSpan(
                children: <TextSpan>[
                  TextSpan(style: textStyle, text: 'More info at '),
                  TextSpan(
                      style: textStyle.copyWith(color: theme.colorScheme.primary),
                      text: 'https://mwageringel.github.io/everest/'),  // TODO make hyperlink clickable or copy to clipboard
                  TextSpan(style: textStyle, text: '.'),
                ],
              ),
            ),
          ],
        ),
        const MyDivider(),
      ],
    );
  }
}

class KeyboardScaffold extends StatelessWidget {
  final Widget title;
  final Widget child;
  final List<Widget>? actions;
  const KeyboardScaffold({required this.title, required this.child, this.actions, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final game = Provider.of<Game>(context);
    final cs = [Expanded(child: child), const Hero(tag: 'thekeyboard', child: Keyboard())];
    return FocusScope(
      debugLabel: 'keyboard-scaffold',
      // skipTraversal: true,  // ideally should be skipped: TODO find a way to make sure traversal and initial focus still work (e.g. move focus along with active question)
      autofocus: true,  // i.e. receives initial input
      onKeyEvent: (node, e) {
        final String? label = e.character?.toUpperCase();
        // for now we ignore KeyRepeatEvent since UI does not rebuild fast enough or skips rebuilding some question widgets
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.backspace) {
          return game.keyPressed('backspace');
        } else if (label != null && e is KeyDownEvent) {
          return game.keyPressed(label);
        } else {
          return KeyEventResult.ignored;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: title,
          actions: actions,
        ),
        body: MediaQuery.of(context).orientation == Orientation.landscape ? Row(children: cs) : Column(children: cs),
      ),
    );
  }
}

class ExamsScreen extends StatelessWidget {
  const ExamsScreen({ Key? key }) : super(key: key);

  void _pushExercises(BuildContext context, String title, Game game, int levelIdx) {
    game.pushLevel(levelIdx);
    final Level level = game.levels[levelIdx];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          assert(game.activeLevel == levelIdx);
          return KeyboardScaffold(
            title: Text(title),
            // Rather than obtaining the current level from game.activeLevel, we provide it directly,
            // since activeLevel can change on popLevel which would cause some flickering
            // (i.e. exercises from a different level getting rendered).
            child: Provider<Level>.value(
              value: level,
              child: const LevelScreen(),
            ),
          );
        },
      ),
    ).then((_) {
      game.popLevel();
    });
  }

  void _pushSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Settings'),
            ),
            body: const SettingsScreen(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaf = KeyboardScaffold(
      title: const Text(appName),
      actions: [
        IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _pushSettings(context),
          tooltip: 'Settings',
        ),
      ],
      child: ListView.builder(
          padding: listPadding,
          itemCount: Provider.of<Game>(context, listen: false).levels.length,  // as number of levels is constant, not listening avoids unnecessary rebuilds
          itemBuilder: (context, levelIdx) => Selector<Game, bool>(
            selector: (context, game) {
              // Rendering exam questions is only relevant when in the exam screen.
              // This deliberately covers a broad range of questions to avoid missing important rebuilds.
              // Fortunately, Flutter only renders the questions that are visible on screen.
              final isRelevant = game.inExamScreen;
              return isRelevant;
            },
            shouldRebuild: (bool oldIsRelevant, bool newIsRelevant) => oldIsRelevant || newIsRelevant,
            builder: (_, isRelevant, child) {  // we do not use the inner context since world changes (such as theme) would not trigger a rebuild
              final game = Provider.of<Game>(context, listen: false);  // listening not needed, since selector already does
              assert((levelIdx > 0) ^ game.levels[levelIdx].exercise.questions.isEmpty);
              final isActive = levelIdx == game.activeLevel && game.inExamScreen;
              final level = game.levels[levelIdx];
              final label = 'Level $levelIdx';
              final unlocked = levelIdx <= game.levelsUnlocked || debugUnlockAll;
              return Material( // fixes hover artifact near keyboard
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    if (levelIdx > 0) const MyDivider(),
                    if (levelIdx > 0) ListTile(
                      title: Text(label, style: _biggerFont),
                      trailing: levelIdx == game.levelsUnlocked && !game.levels[levelIdx].clicked
                        ? BouncingWidget(Icon(Icons.adaptive.arrow_forward))
                        : Icon(unlocked ? Icons.adaptive.arrow_forward : Icons.lock),
                      enabled: unlocked,
                      shape: _listTileRounded,
                      onTap: () {
                        if (levelIdx <= game.levelsUnlocked || debugUnlockAll) {
                          _pushExercises(context, label, game, levelIdx);
                        }
                      },
                    ),
                    if (game.examUnlocked(levelIdx) || debugUnlockAll) ...[
                      if (levelIdx > 0) const MyDivider(),
                      InkWell(
                        child: QuestionsWidget(level.exam.questions,
                          isActive: isActive,
                          focussedQuestion: level.exam.activeIndex,
                          animateStatusWrong: game.doStatusAnimation(),
                          doScroll: game.doScrollAnimation(),
                          onTap: (i) => game.levelTapped(i, inExam: true, levelIdx: levelIdx),
                          trailing: (levelIdx == game.levels.length-1 && game.finished) ? const EndMessage() : null,  // added here for autoscroll
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ),
    );
    return Consumer<Game>(builder: (context, game, child) =>
      WillPopScope(
        onWillPop: () => (
          // this asks for confirmation at back button press to avoid loss of state, when no database is available on web version
          game.db != null ? Future.value(true) : showDialog<bool?>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Saving not available.'),
              content: const Text('All progress will be lost if you exit. Continue?'),
              actions: [
                ElevatedButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
                OutlinedButton(child: const Text('OK'), onPressed: () => Navigator.of(context).pop(true)),
              ],
            ),
          ).then((x) => x ?? false)
        ),
        child: scaf,
      )
    );
  }
}

class EndMessage extends StatelessWidget {
  const EndMessage({Key? key}) : super(key: key);
  @override build(BuildContext context) => ListTile(
    title: Text('Congratulations!', style: _biggerFont.merge(TextStyle(color: Theme.of(context).colorScheme.primary))),
    subtitle: Text(utf8.decode(base64.decode(
      'T3V0c3RhbmRpbmcgYWNjb21wbGlzaG1lbnQhIFlvdSBoYXZlIGV4cGxvcmVkIHRoZSBhcml0aG1ldGlj'
      'cyBvZiB0aGUgZmluaXRlIGZpZWxkcyB3aXRoIDExIGFuZCAxMjEgZWxlbWVudHMuIChEaWQgeW91IG5v'
      'dGljZSBhIHNpbWlsYXJpdHkgd2l0aCBjb21wbGV4IG51bWJlcnM/KQ=='))),
    leading: const Icon(Icons.sentiment_very_satisfied),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<World>(builder: (context, world, child) =>
      MaterialApp(
        title: appName,
        themeMode: world.themeMode,
        theme: FlexThemeData.light(
          fontFamily: 'NotoSansMath',
          scheme: FlexScheme.materialBaseline,
          primary: Colors.indigo,
          surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
          blendLevel: 4,
          appBarOpacity: 0.95,
          subThemesData: const FlexSubThemesData(
            blendOnLevel: 4,
            blendOnColors: false,
          ),
          visualDensity: FlexColorScheme.comfortablePlatformDensity,
        ),
        darkTheme: FlexThemeData.dark(
          fontFamily: 'NotoSansMath',
          scheme: FlexScheme.materialBaseline,
          primary: Colors.indigoAccent,  // better contrast against dark background
          surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
          blendLevel: 10,
          appBarStyle: FlexAppBarStyle.background,
          appBarOpacity: 0.90,
          subThemesData: const FlexSubThemesData(
            blendOnLevel: 10,
          ),
          visualDensity: FlexColorScheme.comfortablePlatformDensity,
          darkIsTrueBlack: world.pureBlack,
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''), // English, no country code
          Locale('de', ''), // German, no country code
        ],
        home: const ExamsScreen(),
      ),
    );
  }
}

// wrapper around game state in order to be able to reset the progress
class World with ChangeNotifier {
  ThemeMode themeMode;
  bool pureBlack;
  final PackageInfo appInfo;
  World(this.appInfo, this.themeMode, this.pureBlack);

  void resetWorld() {
    notifyListeners();  // results in new game getting initialized from database
  }

  void switchTheme({ThemeMode? themeMode, bool? pureBlack}) {
    this.themeMode = themeMode ?? this.themeMode;
    this.pureBlack = pureBlack ?? this.pureBlack;
    notifyListeners();
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Avoid errors caused by flutter upgrade.
  Database? db;
  try {
    db = await openDatabase(
      join(await getDatabasesPath(), 'everest-data.db'),
      onCreate: (db, version) async {
        // note that adding additional tables to existing database file requires some extra steps
        await db.execute(
          'CREATE TABLE $tableKV($columnKey TEXT PRIMARY KEY, $columnValue TEXT)',
        );
        await db.execute(
          'CREATE TABLE $tableAnswers($columnId TEXT PRIMARY KEY, $columnLevel TEXT, $columnQuestion TEXT, $columnInputs TEXT)',
        );
      },
      version: 1,
    );
  } on MissingPluginException {
    db = null;  // database is not available for the web
  }

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['NotoSansMath'], license);
  });

  Future<void> loadGameState(Game game) async {
    // initialization of state from database
    final answers = await game.loadAnswers();
    for (final level in game.levels) {
      for (final question in level.exercise.questions.followedBy(level.exam.questions)) {
        final answer = answers[question.fullId(level)];
        if (answer != null) {
          question.updateInputs(question.unstringifyInputs(answer));
        }
      }
    }
    await game.recomputeExamsState();
  }

  Future<ThemeMode> loadThemeMode(Game game) async {
    String? mode = await game.loadKeyValue(themeModeKey);
    return ThemeMode.values.firstWhere((m) => m.toString() == mode, orElse: () => ThemeMode.system);
  }

  final game0 = Game(db);
  await loadGameState(game0);  // loaded here since `create` is not asynchronous
  final themeMode0 = await loadThemeMode(game0);
  final pureBlack0 = (await game0.loadKeyValue(pureBlackKey)) == true.toString();  // false by default
  final appInfo = await PackageInfo.fromPlatform();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => World(appInfo, themeMode0, pureBlack0)),
        ChangeNotifierProxyProvider<World, Game>(
          create: (context) => game0,  // TODO avoid external variable
          update: (context, world, game) {
            // debugPrint(">>> update of world");
            if (game == null || game.reset) {
              return Game(db);  // a new game without loading state from database
            } else {
              return game;
            }
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}
