import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:everest/game.dart';
import 'package:everest/storage.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';

const appName = 'Everest';
const String themeModeKey = 'settings:themeMode';
const String pureBlackKey = 'settings:pureBlack';

class StatusIcon extends StatelessWidget {
  final QuestionsStatusCovered statusCovered;
  const StatusIcon(this.statusCovered, {Key? key}) : super(key: key);

  static Color color(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    if (light) {
      return const Color(0xff888888);  // default gray
    } else {
      return const Color(0xffa3a8bf); // default bluish-white 0xffd5dbfa detoned
    }
  }

  static QuestionsStatusCovered mkStatusCovered(QuestionsStatus statusSingle, {QuestionsStatus? statusCombined}) {
    // if statusCombined is null, then this is not a multi question
    if (statusSingle == QuestionsStatus.partial) {
      return QuestionsStatusCovered.partial;
    } else if (statusCombined == QuestionsStatus.correct || statusCombined == null && statusSingle == QuestionsStatus.correct) {
      return QuestionsStatusCovered.correct;
    } else if (statusCombined == null && statusSingle == QuestionsStatus.wrong) {
      return QuestionsStatusCovered.wrong;
    } else {  // statusCombined != null and statusSingle is covered (wrong or correct)
      return QuestionsStatusCovered.covered;
    }
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    switch (statusCovered) {
      case QuestionsStatusCovered.partial: return Icon(Icons.circle_outlined, color: color(context));
      case QuestionsStatusCovered.correct: return Icon(Icons.check_circle, color: Color(light ? 0xff1ca23e : 0xff2fae49));
      case QuestionsStatusCovered.wrong: return Icon(Icons.cancel, color: Color(light ? 0xffd51529 : 0xfff6313a));
      case QuestionsStatusCovered.covered: return Icon(Icons.help, color: color(context));
    }
  }
}

class DampedCurve extends Curve {
  // a linearly damped oscillation in reverse
  @override double transformInternal(double t) {
    return cos(16*(1-t))*t;
  }
}
final _dampedCurve = DampedCurve();

class RotateCurve extends Curve {  // 90 rotation
  @override double transformInternal(double t) => t < 0.5 ? 0 : -cos(t*pi);
}
final _rotateCurve = RotateCurve();

class RotateCurve2 extends Curve {  // 180 rotation
  @override double transformInternal(double t) => t < 0.5 ? 0 : cos(2*t*pi);
}
final _rotateCurve2 = RotateCurve2();

class DelayedEaseCurve extends Curve {
  // This delay is tweaked such that the down-scrolling to show the new exam
  // questions (after return to the main screen) looks smooth rather than janky.
  static double delay = 0.35;
  @override double transformInternal(double t) => t < delay ? 0 : Curves.ease.transformInternal((t - delay) / (1 - delay));
}
final _delayedEaseCurve = DelayedEaseCurve();

class StatusIconConnector extends StatelessWidget {
  const StatusIconConnector({Key? key}) : super(key: key);
  @override build(context) => Container(width: 2.5, color: StatusIcon.color(context));
}

class AnimatedStatusIcon extends StatefulWidget {
  final QuestionsStatus statusCombined, statusSingle;
  final bool isFirst, isLast, isMulti;
  final bool animateStatusWrong;
  const AnimatedStatusIcon(this.statusSingle, {required this.statusCombined, required this.animateStatusWrong, Key? key, required this.isFirst, required this.isLast}) :
    isMulti = !(isFirst && isLast),
    super(key: key);

  @override
  State<AnimatedStatusIcon> createState() => _AnimatedStatusIconState();
}
class _AnimatedStatusIconState extends State<AnimatedStatusIcon>
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
    final innerIcon = StatusIcon(StatusIcon.mkStatusCovered(widget.statusSingle, statusCombined: widget.isMulti ? widget.statusCombined : null));
    final animSwitcher = AnimatedSwitcher(  // icon change animation
      duration: const Duration(milliseconds: 330),
      transitionBuilder: (Widget child, Animation<double> animation) => VerticalScaleTransition(child, animation, horizontal: widget.isMulti),
      switchInCurve: _rotateCurve,
      switchOutCurve: _rotateCurve,
      child: Container(
        key: ValueKey<QuestionsStatusCovered>(innerIcon.statusCovered),
        child: innerIcon,
      ),
    );
    if (widget.animateStatusWrong && widget.statusCombined == QuestionsStatus.wrong) {
      _runAnimation();
    }
    Widget iconWithConnector = SlideTransition(  // error animation
      position: _animation,
      child: !widget.isMulti ?
        animSwitcher :
        Column(
          children: [
            Expanded(child: Visibility(visible: !widget.isFirst, child: const StatusIconConnector())),
            animSwitcher,
            Expanded(child: Visibility(visible: !widget.isLast, child: const StatusIconConnector())),
          ],
        ),
    );
    return iconWithConnector;
  }
}

class VerticalScaleTransition extends StatefulWidget {
  final Widget child;
  final Animation<double> animation;
  final bool horizontal;
  const VerticalScaleTransition(this.child, this.animation, {this.horizontal = false, Key? key}) : super(key: key);
  @override createState() => _VerticalScaleTransitionState();
}
class _VerticalScaleTransitionState extends State<VerticalScaleTransition> {
  double scaleY = 1;
  void _update() => setState(() => scaleY = widget.animation.value);
  @override Widget build(BuildContext context) => Transform.scale(
    scaleX: widget.horizontal ? scaleY : 1.0,
    scaleY: widget.horizontal ? 1.0 : scaleY,
    child: widget.child
  );
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
  final ScrollType doScroll;
  final void Function() doneScrollAnimation;
  final void Function(int) onTap;
  final Widget? trailing;
  const QuestionsWidget(this.questions,
    {required this.isActive, required this.focussedQuestion, required bool animateStatusWrong,
     required ScrollType doScroll, required this.doneScrollAnimation, required this.onTap, this.trailing, Key? key}):
    animateStatusWrong = animateStatusWrong && isActive,
    doScroll = isActive ? doScroll : ScrollType.none,
    super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = jointStatus(questions);  // TODO cache this?
    final c = Column(children: [
      ...Iterable<Widget>.generate(questions.length, (i) {
        // the following is more direct than expr.str() and works since all variables appear exactly once from left to right
        final q = questions[i].inputs.fold<String>(questions[i].q, (q, s) => q.replaceFirst('?', s));
        Widget? t;
        if (isActive && i == focussedQuestion) {
          var j = q.indexOf('?');
          if (j == -1) {
            j = questions[i].q.indexOf('?'); // relies on all replacements being single characters
          }
          if (j != -1) {
            t = Text.rich(
              TextSpan(text: q.substring(0, j), style: _biggerFontMath, children: [
                WidgetSpan( // with padding
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).textSelectionTheme.selectionColor,
                      borderRadius: const BorderRadius.all(Radius.circular(3.0)),
                    ),
                    child: Text(q.substring(j, j+1),
                      style: _biggerFontMath,
                      textScaler: TextScaler.noScaling,  // important in order to avoid scaling twice with enlarged system font settings
                    ),
                  ),
                ),
                ...(q.length > j+1 ? [TextSpan(text: q.substring(j+1))] : []),
              ]),
              textScaler: MediaQuery.textScalerOf(context),  // for consistent font sizes with enlarged system font settings
            );
          }
        }
        t ??= Text(q, style: _biggerFontMath);
        return ListTile(
          title: t,
          trailing: AnimatedStatusIcon(
            questions[i].status(),
            statusCombined: status,
            animateStatusWrong: animateStatusWrong,
            isFirst: i == 0,
            isLast: i == questions.length - 1,
          ),
          shape: _listTileRounded,
          onTap: () => onTap(i)
        );
      }),
      if (trailing != null) trailing!,
    ]);
    if (doScroll != ScrollType.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // for details about scrolling see https://stackoverflow.com/q/49153087
        Scrollable.ensureVisible(context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: doScroll == ScrollType.jump ? Duration(milliseconds: (800 / (1 - DelayedEaseCurve.delay)).round()) : const Duration(milliseconds: 800),
          curve: doScroll == ScrollType.jump ? _delayedEaseCurve : Curves.ease,  // formerly this was a `jump`, now it is just a delayed smooth scroll
        );
        doneScrollAnimation();
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
  int _cycleCount = 0;
  bool _showInfo = false;  // after some cycles, show info icon to draw attention to exercises page

  // instead of a permanent long animation, we use a timer with a short animation to avoid permanent high cpu usage
  late final Timer _timer;
  _BouncingWidgetState() {
    // despite the `late`, defining the timer here in the constructor (in contrast
    // to initializing it at declaration) ensures that it is actually started
    _timer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      await _controller.forward();
      await _controller.reverse();
      _cycleCount++;
      if (_cycleCount >= 3 && !_showInfo) {
        setState(() => _showInfo = true);
      }
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showInfo) const Icon(Icons.info_outline),
          widget.child,
        ],
      ),
    );
  }
}

Iterable<A> interleave<A>(Iterable<A> it, A separator) {
  return it.expand((a) => [separator, a]).skip(1);
}

const listPadding = EdgeInsets.all(8.0);
const _biggerFont = TextStyle(fontSize: 18.0);
final _biggerFontMath = _biggerFont.copyWith(fontFamily: 'NotoSansMath', fontFamilyFallback: ['NotoSans']);
final _biggerFontMathButton = _biggerFontMath.copyWith(fontSize: 20.0);  // NotoSansMath appears to be better vertically centered than NotoSans

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
            child: _keyIcons.containsKey(label) ? Icon(_keyIcons[label], size: 26) : Text(label, style: _biggerFontMathButton),
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
        color: Theme.of(context).bottomAppBarTheme.color,
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
                doneScrollAnimation: game.doneScrollAnimation,
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

class ThemeModeLabel extends StatelessWidget {
  final ThemeMode _mode;
  const ThemeModeLabel(this._mode, { Key? key }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final String s;
    switch (_mode) {
      case ThemeMode.system: s = AppLocalizations.of(context)!.themeSystem; break;
      case ThemeMode.light: s = AppLocalizations.of(context)!.themeLight; break;
      case ThemeMode.dark: s = AppLocalizations.of(context)!.themeDark; break;
    }
    return Text(s);
  }
}

class MoreInfoMessage extends StatelessWidget {
  const MoreInfoMessage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle textStyle = theme.textTheme.bodyMedium!;
    final Uri url = Uri.parse('https://mwageringel.github.io/everest/');
    final List<String> textFragments = AppLocalizations.of(context)!.moreInfo('__URL__').split('__URL__');  // fragments before and after the url
    return Text.rich( // important for vertical alignment
      TextSpan(
        children: <InlineSpan>[
          ...(textFragments.isNotEmpty && textFragments[0].isNotEmpty ? [TextSpan(style: textStyle, text: textFragments[0])] : []),
          WidgetSpan(
            child: Link(
              uri: url,
              builder: (context, followLink) => InkWell(
                // opens new tab in web (in contrast to `followLink`) and external browser on android
                onTap: () => launchUrl(url, mode: LaunchMode.externalApplication),
                child: Text(url.toString(), style: textStyle.copyWith(color: theme.colorScheme.primary)),
              ),
            ),
          ),
          ...(textFragments.length > 1 && textFragments[1].isNotEmpty ? [TextSpan(style: textStyle, text: textFragments[1])] : []),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({ Key? key }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: listPadding,
      children: [
        ListTile(
          leading: const Icon(Icons.settings_brightness),
          title: Text(AppLocalizations.of(context)!.theme),
        ),
        Consumer2<World, Game>(builder: (context, world, game, child) =>
          Column(
            children: [
              ...([ThemeMode.light, ThemeMode.system, ThemeMode.dark].map((ThemeMode m) =>
                RadioListTile<ThemeMode>(
                  value: m,
                  groupValue: world.themeMode,
                  title: ThemeModeLabel(m),
                  onChanged: (mode) async {
                    world.switchTheme(themeMode: m);
                    return game.db.storeKeyValue(themeModeKey, m.toString());
                  },
                ),
              )),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.darkThemeBlackBackground),
                subtitle: Text(AppLocalizations.of(context)!.darkThemeBlackBackgroundSubtitle),
                value: world.pureBlack,
                onChanged: (bool value) async {
                  world.switchTheme(pureBlack: value);
                  return game.db.storeKeyValue(pureBlackKey, value.toString());
                },
              ),
            ],
          ),
        ),
        const MyDivider(),
        Consumer2<World, Game>(builder: (context, world, game, child) =>
          ListTile(
            leading: AnimatedSwitcher(
              duration: const Duration(milliseconds: 660),
              transitionBuilder: (Widget child, Animation<double> animation) => VerticalScaleTransition(child, animation, horizontal: true),
              switchInCurve: _rotateCurve2,
              switchOutCurve: _rotateCurve2,
              child: Container(
                key: ObjectKey(game),
                child: const Icon(Icons.restore),
              ),
            ),
            title: Text(AppLocalizations.of(context)!.restart),
            subtitle: Text(AppLocalizations.of(context)!.restartSubtitle),
            onLongPress: () async {
              await game.resetProgress();
              world.resetGame(Game.initializedGame(game.db, loadProgress: false));
            },
          ),
        ),
        const MyDivider(),
        AboutListTile(
          icon: const Icon(Icons.info_outline),
          applicationVersion: AppLocalizations.of(context)!.version(Provider.of<World>(context).appInfo?.version),
          aboutBoxChildren: const [
            MoreInfoMessage(),
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

// This widget groups the level title and the three exam questions together
// in order to allow automatic scrolling even if the questions are still hidden.
class ExamWidget extends StatelessWidget {
  final int levelIdx;
  final Game game;
  final Level level;
  final bool isActive, unlocked, _showExamQuestions;

  ExamWidget(this.game, {required this.levelIdx, required this.isActive, Key? key}):
    level = game.levels[levelIdx],
    unlocked = (levelIdx <= game.levelsUnlocked || debugUnlockAll),
    _showExamQuestions = (game.examUnlocked(levelIdx) || debugUnlockAll),
    super(key: key);

  void _pushExercises(BuildContext context, String label) {
    game.pushLevel(levelIdx);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          assert(game.activeLevel == levelIdx);
          return KeyboardScaffold(
            title: Text(label),
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

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.levelTitle(levelIdx);
    return Column(
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
            if (unlocked) {
              _pushExercises(context, label);
            }
          },
        ),
        if (levelIdx > 0 && _showExamQuestions) const MyDivider(),
        QuestionsWidget(
          _showExamQuestions ? level.exam.questions : [],  // we render the widget even with 0 questions in order to support autoscroll when the questions are hidden for the first few levels
          isActive: isActive,
          focussedQuestion: level.exam.activeIndex,
          animateStatusWrong: game.doStatusAnimation(),
          doScroll: game.doScrollAnimation(),
          doneScrollAnimation: game.doneScrollAnimation,
          onTap: (i) => game.levelTapped(i, inExam: true, levelIdx: levelIdx),
          trailing: (levelIdx == game.levels.length-1 && game.finished) ? const EndMessage() : null,  // added here for autoscroll
        ),
      ],
    );
  }
}

class ExamsScreen extends StatelessWidget {
  const ExamsScreen({ Key? key }) : super(key: key);

  void _pushSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.settings),
            ),
            body: const SettingsScreen(),
          );
        },
      ),
    ).then((_) {
      Provider.of<Game>(context, listen: false).popSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaf = KeyboardScaffold(
      title: const Text(appName),
      actions: [
        IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _pushSettings(context),
          tooltip: AppLocalizations.of(context)!.settings,
        ),
      ],
      child: ListView.builder(
          padding: listPadding,
          itemCount: Provider.of<Game>(context, listen: false).levels.length,  // as number of levels is constant, not listening avoids unnecessary rebuilds
          itemBuilder: (context, levelIdx) => Selector<Game, bool>(
            selector: (context, game) {
              // Rendering exam questions is only relevant when in the exam screen.
              // (Flutter only renders the questions that are visible on screen.)
              // This triggers full rebuilds whenever exiting a subpage (to account for resets/theme changes/unlocks)
              // and selective rebuilds for levels actively changing.
              final isRelevant = game.inExamScreen && (levelIdx == game.activeLevel || game.doRedrawEverything());
              return isRelevant;
            },
            shouldRebuild: (bool oldIsRelevant, bool newIsRelevant) => oldIsRelevant || newIsRelevant,
            builder: (_, isRelevant, child) {  // we do not use the inner context since world changes (such as theme) would not trigger a rebuild
              final game = Provider.of<Game>(context, listen: false);  // listening not needed, since selector already does
              assert((levelIdx > 0) ^ game.levels[levelIdx].exercise.questions.isEmpty);
              final isActive = levelIdx == game.activeLevel && game.inExamScreen;
              return Material( // fixes hover artifact near keyboard
                color: Theme.of(context).scaffoldBackgroundColor,
                child: ExamWidget(game, levelIdx: levelIdx, isActive: isActive),
              );
            },
          ),
      ),
    );
    return Consumer<Game>(builder: (context, game, child) =>
      WillPopScope(
        onWillPop: () => (
          // this asks for confirmation at back button press to avoid loss of state, when no database is available on some platform
          game.db.isUsable() ? Future.value(true) : showDialog<bool?>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.exitDialogTitle),
              content: Text(AppLocalizations.of(context)!.exitDialogContent),
              actions: [
                ElevatedButton(child: Text(AppLocalizations.of(context)!.dialogCancel), onPressed: () => Navigator.of(context).pop(false)),
                OutlinedButton(child: Text(AppLocalizations.of(context)!.dialogOk), onPressed: () => Navigator.of(context).pop(true)),
              ],
            ),
          ).then((x) => x ?? false)
        ),
        child: scaf,
      )
    );
  }
}

class ExtendedMessage extends StatelessWidget {
  const ExtendedMessage({Key? key}) : super(key: key);
  @override build(BuildContext context) => Text(
    utf8.decode(base64.decode(AppLocalizations.of(context)!.extendedMessage))
  );
}

class EndMessage extends StatelessWidget {
  const EndMessage({Key? key}) : super(key: key);
  @override build(BuildContext context) => ListTile(
    title: Text(AppLocalizations.of(context)!.endMessage, style: _biggerFont.merge(TextStyle(color: Theme.of(context).colorScheme.primary))),
    subtitle: const ExtendedMessage(),
    leading: const Icon(Icons.sentiment_very_satisfied),
  );
}

class MyApp extends StatelessWidget {
  final World world0;
  final Game _game0;

  const MyApp(this.world0, this._game0, {Key? key}) : super(key: key);

  static ThemeData lightTheme() => FlexThemeData.light(
    fontFamily: 'NotoSans',
    scheme: FlexScheme.materialBaseline,
    primary: Colors.indigo,
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
    blendLevel: 4,
    appBarOpacity: 0.95,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 4,
      blendOnColors: false,
      blendTextTheme: true,  // blends theme colors into text
      tintedDisabledControls: true,
      outlinedButtonOutlineSchemeColor: SchemeColor.primary,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: false,
  );

  static ThemeData darkTheme(bool pureBlack) => FlexThemeData.dark(
    fontFamily: 'NotoSans',
    scheme: FlexScheme.materialBaseline,
    primary: Colors.indigoAccent,  // better contrast against dark background
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
    blendLevel: 10,
    appBarStyle: FlexAppBarStyle.background,
    appBarOpacity: 0.90,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      blendTextTheme: true,  // blends theme colors into text
      tintedDisabledControls: true,
      outlinedButtonOutlineSchemeColor: SchemeColor.primary,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: false,
    darkIsTrueBlack: pureBlack,
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<World>.value(
      value: world0,
      child: Consumer<World>(builder: (context, world, child) {
        return FutureProvider<Game>.value(
          value: world.gameFuture,  // differs from game0 once resetGame is called
          initialData: _game0,  // After game has been reset, we should avoid showing this old game progress, but since reset happens on another page, it is likely never visible
          child: Consumer<Game>(builder: (context, game, child) {
            return ChangeNotifierProvider.value(
              value: game,
              child: MaterialApp(
                title: appName,
                themeMode: world.themeMode,
                theme: lightTheme(),
                darkTheme: darkTheme(world.pureBlack),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const ExamsScreen(),
              ),
            );
          }),
        );
      }),
    );
  }
}

// wrapper around game state in order to be able to reset the progress
class World with ChangeNotifier {
  ThemeMode themeMode;
  bool pureBlack;
  final PackageInfo? appInfo;
  Future<Game> gameFuture;
  World(this.appInfo, this.themeMode, this.pureBlack, this.gameFuture);

  void resetGame(Future<Game> newGame) {
    gameFuture = newGame;
    notifyListeners();
  }

  void switchTheme({ThemeMode? themeMode, bool? pureBlack}) {
    this.themeMode = themeMode ?? this.themeMode;
    this.pureBlack = pureBlack ?? this.pureBlack;
    notifyListeners();
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Avoid errors caused by flutter upgrade.
  DatabaseWrapper db = await DatabaseWrapper.create();

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['NotoSansMath', 'NotoSans'], license);
  });

  Future<ThemeMode> loadThemeMode(Game game) async {
    String? mode = await game.db.loadKeyValue(themeModeKey);
    return ThemeMode.values.firstWhere((m) => m.toString() == mode, orElse: () => ThemeMode.system);
  }

  // loading the game from the database is quick, so we do it synchronously here, so that the initial render can already show the actual progress
  final game0 = await Game.initializedGame(db, loadProgress: true);
  final themeMode0 = await loadThemeMode(game0);
  final pureBlack0 = (await game0.db.loadKeyValue(pureBlackKey)) == true.toString();  // false by default
  final appInfo = await PackageInfo.fromPlatform();
  final world0 = World(appInfo, themeMode0, pureBlack0, Future.value(game0));
  runApp(MyApp(world0, game0));
}
