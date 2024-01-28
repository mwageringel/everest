import 'dart:async';
import 'package:flutter/foundation.dart' show listEquals, ChangeNotifier;
import 'package:everest/expressions.dart';
import 'package:everest/storage.dart';
import 'package:flutter/widgets.dart';

const debugUnlockAll = false;
const String tableKV = 'keyvalues', tableAnswers = 'answers';
const String columnKey = 'key', columnValue = 'value', columnId = 'id', columnLevel = 'level', columnQuestion = 'question', columnInputs = 'inputs';
const String levelsUnlockedKey = 'game:levelsUnlocked';

enum QuestionsStatus { wrong, partial, correct }
enum QuestionsStatusCovered { wrong, partial, correct, covered }
QuestionsStatus combineStatus(QuestionsStatus a, QuestionsStatus b) {
  if (a == QuestionsStatus.correct) {
    return b;
  } else if (a == QuestionsStatus.partial || b == QuestionsStatus.partial) {
    return QuestionsStatus.partial;
  } else { // a wrong, b not partial
    return QuestionsStatus.wrong;
  }
}
QuestionsStatus jointStatus(Iterable<Question> questions) {
  return questions.map((q) => q.status()).fold(QuestionsStatus.correct, combineStatus);
}

class Question {
  final Expression<bool> expr;
  final List<Var<dynamic>> vars;
  late final String q;  // pretty representation
  late final String id;  // more canonical representation for database
  List<String>? _cachedSolution;
  final List<String> inputs = [];  // we use String instead of F because of X
  bool isPartial;
  static const _dottedFence = '⦙', _equiv = '≡';

  Question(this.expr, this.vars, {this.isPartial = false}) {
    final s = expr.toString();
    q = s.replaceAll('=', _equiv).replaceAll('.', _dottedFence);
    id = s.replaceAll(' ', '');
    final numBlanks = '?'.allMatches(q).length;
    assert(numBlanks == numVariables);
  }

  int get numVariables => vars.length;

  QuestionsStatus status() {
    if (inputs.length < numVariables) {
      return QuestionsStatus.partial;
    } else if (_cachedSolution != null && listEquals(inputs, _cachedSolution)) {
      return QuestionsStatus.correct;
    } else if (expr.eval(Map.fromIterables(vars, inputs.map(F.parse)))) {
      _cachedSolution = List.unmodifiable(inputs);  // we cache a copy of the last correct solution only
      return QuestionsStatus.correct;
    } else {
      return QuestionsStatus.wrong;
    }
  }

  @override
  toString() => 'Q($q, ${inputs.join(',')})';

  String stringifyInputs() => inputs.join(';');
  List<String> unstringifyInputs(String s) => s == '' ? [] : s.split(';');
  String fullId(Level level) => '${level.id}:$id';

  Map<String, String> toMap(Level level) {
    return {
      columnId: fullId(level),
      columnLevel: level.id,
      columnQuestion: q,
      columnInputs: stringifyInputs(),
    };
  }

  void updateInputs(List<String> newInputs) {
    if (newInputs.length <= numVariables) {
      inputs.clear();
      inputs.addAll(newInputs);
    }
    // otherwise, we ignore the change to avoid inconsistencies
  }
}

class QuestionsWithIndex {
  final List<Question> questions;
  int activeIndex = 0;
  QuestionsWithIndex(this.questions);
  Question get activeQuestion => questions[activeIndex];

  Iterable<Question> _previousQuestions(int idx) sync* {
    for (var j = idx - 1; j >= 0; j--) {
      yield questions[j];
    }
  }

  QuestionsStatus activeFullQuestionStatus() {
    int idx = activeIndex;
    while (questions[idx].isPartial) {
      idx++;
    }
    final s = combineStatus(
      questions[idx].status(),
      jointStatus(_previousQuestions(idx).takeWhile((q) => q.isPartial)));
    return s;
  }

  Iterable<List<MapEntry<int, Question>>> fullQuestions() sync* {
    List<MapEntry<int, Question>> buf = [];
    for (final e in questions.asMap().entries) {
      buf.add(e);
      if (!e.value.isPartial) {
        yield buf;
        buf = [];
      }
    }
    assert(buf.isEmpty, "last question must not be partial");
  }
}

class Level {
  final String id;
  final QuestionsWithIndex exercise;
  final QuestionsWithIndex exam;
  bool clicked = false;
  Level(this.id, List<Question> questions, List<Question> examQuestions):
      exercise = QuestionsWithIndex(questions),
      exam = QuestionsWithIndex(examQuestions) {
    exam.questions.asMap().forEach((i, q) {
      q.isPartial = i < exam.questions.length - 1;
    });
  }

  @override
  toString() {
    return 'Level(questions: [${exercise.questions.join(',')}], examQuestions: [${exam.questions.join(',')}], activeQuestion: ${exercise.activeIndex}, activeExamQuestion: ${exam.activeIndex})';
  }

  bool isSolved() => jointStatus(exam.questions) == QuestionsStatus.correct;
}

enum ScrollType { none, smooth, jump }

final Var<F> y = Var(), z = Var();
final yz = dot(y, z);
typedef Q = Question;
Question q1(Expression<F> lhs, {bool isPartial = false}) {
  return Question(lhs.eq(y), [y], isPartial: isPartial);
}
Question q2(Expression<G> lhs, {bool isPartial = false}) {
  return Question(lhs.eq(yz), [y, z], isPartial: isPartial);
}

class Game with ChangeNotifier {
  final List<Level> levels = [
    Level("0", [], [q1(C(1) + C(2))]),
    Level("0.5", [
      q1(C(3) + C(4)),
      q1(C(4) + C(3)),
      q1(C(2) + C(6)),
      q1(C(1) + C(5)),
      q1(C(0) + X),
      q1(C(3) + C(7)),
      q1(C(2) + C(7)),
      q1(C(6) + C(4)),
      q1(C(9) + C(1)),
      q1(C(0) + C(0), isPartial: true),
      q1(C(3) + C(1)),
      q1(C(3) + X),
      q1(C(4) + X),
      q1(X + C(6)),
      q1(X + C(4)),
    ], [
      q1(C(5) + C(5)),
      q1(C(1) + X),
      q1(X + C(9)),
    ]),
    Level("1", [ // addition
      q1(C(5) + C(7)),
      q1(C(5) + C(8)),
      q1(C(6) + C(6)),
      q1(C(9) + C(8)),
      q1(C(7) + C(7)),
      q1(C(5) + X),
      q1(C(4) + C(9)),
      q1(C(9) + C(6)),
    ], [
      q1(C(7) + C(8)),
      q1(C(2) + C(9)),
      q1(X + X),
    ]),
    Level("2", [ // subtraction
      q1(C(6) - C(3)),
      q1(C(0) - C(3)),
      q1(-C(3)),
      q1(-C(5)),
      q1(C(7) - C(8)),
      q1(C(2) - C(6)),
      q1(C(1) - C(9)),
    ], [
      q1(X - C(7)),
      q1(-C(1)),
      q1(-X),
    ]),
    Level("3", [ // multiplication
      q1(C(2) * C(3)), // below 11
      q1(C(5) * C(5)), // first above 22
      q1(C(6) * C(9)), // way larger
      q1(C(1) * C(0)), // 1
      q1(C(1) * X), // 1
      q1(C(7) * C(5)),
      q1(X * C(6)),
      q1(C(9) * C(9)),
    ], [
      q1(C(7) * C(8)),
      q1(X * C(0)),
      q1(X * X),
    ]),
    Level("4", [ // division by 2
      q1(C(4) * C(2)),
      q1(C(8) / C(2)),
      q1(C(6) * C(2)),
      q1(C(1) / C(2)),
      q1(C(3) / C(2)),
      q1(C(7) * C(2)),
      q1(C(2) / C(2)),
      q1(C(6) / C(2)),
      q1(C(7) / C(2)),
    ], [
      q1(C(5) / C(2)),
      q1(C(9) / C(2)),
      q1(X / C(2)),
    ]),
    Level("5", [ // division
      q1(C(1) / C(3)),
      q1(C(2) / C(3)),  // double of previous
      q1(C(5) / C(4)),
      q1(X / C(4)),  // double of previous
      q1(C(1) / C(6)),  // denominator of exam
      q1(C(1) / C(9)),
      q1(C(3) / C(8)),
      q1(C(7) / C(5)),
    ], [
      q1(C(1) / C(7)),
      q1(C(1) / X),
      q1(C(5) / C(6)),
    ]),
    Level("6", [ // addition
      q2(dot(1,3) + dot(4,0)),
      q2(dot(4,2) + dot(8,0)), // intentionally 1.2 vs 12=4+8
      q2(dot(4,4) + dot(0,1)),
      q2(dot(4,4) + dot(0,8)),
      q2(dot(5,5) + dot(9,9)), // componentwise structure
      q2(dot(7,X) + dot(X,5)),
      q2(dot(6,7) + dot(9,7)),
    ], [
      q2(dot(0,X) + dot(X,X)),
      q2(dot(5,5) + dot(8,X)),
      q2(dot(X,6) + dot(X,6)),
    ]),
    Level("7", [ // multiplication (result partial 1)
      q2(dot(2,0) * dot(4,0)),
      q2(dot(3,0) * dot(6,0)),
      q2(dot(8,0) * dot(8,0)),
      Q((dot(0,1) * dot(0,1)).eq(dot(y,0)), [y]),
      q2(dot(0,1) * dot(0,3)),
      q2(dot(0,X) * dot(0,1)),
      q2(dot(0,5) * dot(0,4)),
      q2(dot(0,8) * dot(0,8)),
    ], [
      q2(dot(7,0) * dot(9,0)),
      q2(dot(0,7) * dot(0,9)),
      q2(dot(0,X) * dot(0,X)),
    ]),
    Level("8", [ // multiplication (result partial 2)
      q2(dot(1,0) * dot(7,0)),
      q2(dot(1,0) * dot(X,0)),
      q2(dot(1,0) * dot(0,1)),
      q2(dot(2,0) * dot(0,1)),
      q2(dot(2,0) * dot(0,7)),
      q2(dot(2,0) * dot(1,0)),
      q2(dot(0,2) * dot(1,0)), // commutative
      q2(dot(0,5) * dot(6,0)),
      q2(dot(0,8) * dot(3,0)),
      q2(dot(0,6) * dot(9,0)),
    ], [
      q2(dot(7,0) * dot(0,3)),
      q2(dot(0,7) * dot(3,0)),
      q2(dot(0,X) * dot(X,0)),
    ]),
    Level("8.1", [ // multiplication (factor partial 1)
      q2(dot(1,0) * dot(2,0)),
      q2(dot(1,0) * dot(0,4)),
      q2(dot(1,0) * dot(2,4)),
      q2(dot(2,0) * dot(2,4)),
      q2(dot(4,0) * dot(2,4)),
      q2(dot(7,0) * dot(1,8)),
      q2(dot(7,3) * dot(7,0)), // commutative
      q2(dot(2,9) * dot(2,0)),
    ], [
      q2(dot(6,0) * dot(3,9)),
      q2(dot(2,8) * dot(5,0)),
      q2(dot(7,X) * dot(X,0)),
    ]),
    Level("8.2", [ // multiplication (factor partial 2)
      q2(dot(1,0) * dot(0,1)),
      q2(dot(0,3) * dot(0,1)),
      q2(dot(1,3) * dot(0,1)), // first complicated case
      q2(dot(1,3) * dot(0,5)),
      q2(dot(3,0) * dot(0,1)),
      q2(dot(0,9) * dot(0,1)),
      q2(dot(3,9) * dot(0,1)),
      q2(dot(8,X) * dot(0,1)),
      q2(dot(2,6) * dot(0,4)),
      q2(dot(0,1) * dot(5,4)), // commutative
      q2(dot(0,7) * dot(7,3)),
    ], [
      q2(dot(5,8) * dot(0,4)),
      q2(dot(0,6) * dot(3,9)),
      q2(dot(1,1) * dot(0,1)),
    ]),
    Level("9", [ // multiplication (general)
      q2(dot(1,3) * dot(0,4)),
      q2(dot(1,3) * dot(2,0)),
      q2(dot(1,3) * dot(2,4)), // first general case
      q2(dot(3,3) * dot(0,1)),
      q2(dot(3,3) * dot(5,0)),
      q2(dot(3,3) * dot(5,1)), // repetition
      q2(dot(4,3) * dot(0,5), isPartial: true),
      q2(dot(4,3) * dot(3,0), isPartial: true),
      q2(dot(4,3) * dot(3,5)), // repetition
      q2(dot(2,5) * dot(0,4), isPartial: true),
      q2(dot(2,5) * dot(2,0), isPartial: true),
      q2(dot(2,5) * dot(2,4)), // repetition
      q2(dot(5,1) * dot(6,4)), // direct
      q2(dot(9,1) * dot(1,9)), // direct
    ], [
      q2(dot(1,1) * dot(1,1)),
      q2(dot(X,X) * dot(6,4)),
      q2(dot(6,7) * dot(8,9)),
    ]),
    Level("9.1", [
      q2(dot(0,7) * dot(0,4)),
      q2(-dot(0,4) * dot(0,4)),
      q2(dot(2,7) * dot(2,4)),
      Q((dot(2,y) * dot(2,1)).eq(dot(z,0)), [y,z]), // well-defined for non-zero first component
      Q((dot(1,y) * dot(1,3)).eq(dot(z,0)), [y,z]),
      Q((dot(2,y) * dot(2,2)).eq(dot(z,0)), [y,z]),
      Q((dot(5,y) * dot(5,5)).eq(dot(z,0)), [y,z]),
    ], [
      Q((dot(1,y) * dot(1,9)).eq(dot(z,0)), [y,z]),
      Q((dot(3,y) * dot(3,X)).eq(dot(z,0)), [y,z]),
      Q((dot(X,y) * dot(X,X)).eq(dot(z,0)), [y,z]),
    ]),
    Level("9.2", [ // division (divisor partial)
      q2(dot(4,0) / dot(2,0)),
      q2(dot(2,0) / dot(2,0)),
      q2(dot(1,0) / dot(2,0)),
      q2(dot(1,6) / dot(2,0)),
      q2(dot(6,4) / dot(3,0)),
      q2(dot(5,2) / dot(4,0)),
    ], [
      q2(dot(8,5) / dot(2,0)),
      q2(dot(3,X) / dot(7,0)),
      q2(dot(6,2) / dot(X,0)),
    ]),
    Level("10", [ // division (general)
      Q((dot(1,y) * dot(1,1)).eq(dot(z,0)), [y,z]),
      q2(dot(2,0) / dot(1,1)),
      q2(dot(1,0) / dot(1,1)),
      Q((dot(1,y) * dot(1,2)).eq(dot(z,0)), [y,z]),
      q2(dot(1,0) / dot(1,2)), // more direct
      Q((dot(1,y) * dot(1,3)).eq(dot(z,0)), [y,z]),
      q2(dot(1,0) / dot(1,3)), // repetition
      q2(dot(5,0) / dot(1,3)),
      Q((dot(4,y) * dot(4,5)).eq(dot(z,0)), [y,z], isPartial: true),
      q2(dot(1,0) / dot(4,5)), // repetition
      q2(dot(2,7) / dot(4,5)), // fully general case
      Q((dot(8,y) * dot(8,9)).eq(dot(z,0)), [y,z], isPartial: true),
      q2(dot(1,0) / dot(8,9), isPartial: true),
      q2(dot(2,6) / dot(8,9)), // repetition
      q2(dot(1,0) / dot(5,4)), // direct
      q2(dot(1,0) / dot(9,2)), // direct
      q2(dot(2,3) / dot(4,7)), // direct
      q2(dot(8,5) / dot(3,6)), // direct
    ], [
      q2(dot(1,0) / dot(2,1)),
      q2(dot(3,1) / dot(3,X)),
      q2(dot(5,8) / dot(0,1)),
    ]),
    Level("11", [ // squares
      Q(dot(4,0).eq(dot(y,0).square()), [y]),
      Q(dot(9,0).eq(yz.square()), [y,z]),
      Q(dot(1,0).eq(yz.square()), [y,z]),
      Q(dot(X,0).eq(yz.square()), [y,z]),
    ], [
      Q(dot(5,0).eq(yz.square()), [y,z]),
      Q(dot(2,0).eq(yz.square()), [y,z]),
      Q(dot(8,0).eq(yz.square()), [y,z]),
    ]),
  ];

  final DatabaseWrapper db;
  int _inputCount = 0;
  int _doStatusAnimationAtCount = -1;
  int _doScrollAtCount = -1;
  int _doJumpAtCount = -1;
  int _doRedrawAtCount = -1;
  Game(this.db);

  bool doStatusAnimation() {
    return _doStatusAnimationAtCount == _inputCount;
  }
  ScrollType doScrollAnimation() {
    if (_doJumpAtCount == _inputCount) {
      return ScrollType.jump;
    } else if (_doScrollAtCount == _inputCount) {
      return ScrollType.smooth;
    } else {
      return ScrollType.none;
    }
  }
  void doneScrollAnimation() {
    if (doScrollAnimation() != ScrollType.none) {
      _inputCount++;  // ensures that we only scroll once (otherwise, scrolling up and back down manually would retrigger the scroll animation)
    } else {
      // We have already left the scroll conditions due to some other input, so we do nothing to reduce risk of messing up the state.
      // TODO A safer implementation would pass the original _inputCount as token and check
      // whether it is still the same, or whether a scroll has already been performed for that token.
    }
  }
  bool doRedrawEverything() {
    return _doRedrawAtCount == _inputCount;
  }

  final List<int> _activeLevelStack = [0];
  int get activeLevel => _activeLevelStack.last;
  set activeLevel(int level) {
    _activeLevelStack[_activeLevelStack.length - 1] = level;
  }
  bool get inExamScreen => _activeLevelStack.length == 1;
  int levelsUnlocked = 0;
  bool get finished => levelsUnlocked >= levels.length;
  // To make it more intuitive to navigate to the exercises page, we initially hide the exams on the first few levels.
  // For higher levels, we show the exam immediately to motivate the goal of the level and to allow shortcuts.
  bool _exam123Unlocked(int i) => levelsUnlocked > i || levels[i].clicked || levels[i].exercise.questions.any((q) => q.inputs.isNotEmpty);
  bool examUnlocked(int i) => i <= levelsUnlocked && (i < 1 || i > 3 || _exam123Unlocked(i)) || debugUnlockAll;

  KeyEventResult keyPressed(String key) {
    if (key != 'backspace' && RegExp(r"[\dX]$").matchAsPrefix(key) == null) {
      return KeyEventResult.ignored;  // ignore invalid keys
    }
    final l = levels[activeLevel];
    final q = inExamScreen ? l.exam.activeQuestion : l.exercise.activeQuestion;
    final numBlanks = '?'.allMatches(q.q).length;
    if (!inExamScreen || examUnlocked(activeLevel)) {
      _inputCount++;
      if (key == 'backspace') {
        if (q.inputs.isNotEmpty) {
          q.inputs.removeLast();
        } else {
          _movePrevious(l);
        }
      } else { // ordinary key
        if (q.inputs.length >= numBlanks) {
          q.inputs.clear();
        }
        q.inputs.add(key);
        if (q.inputs.length == numBlanks) {
          _moveNext(l);
        }
      }
    } // else this exam is not yet unlocked, so we ignore the input (relevant for exam 1 only)
    notifyListeners();
    db.storeAnswer(l, q).then((_) => storeLevelsUnlocked());  // asynchronous (order of database store events is not that important)
    return KeyEventResult.handled;
  }

  void _movePrevious(Level l) {
    final qq = inExamScreen ? l.exam : l.exercise;
    if (qq.activeIndex > 0) {
      qq.activeIndex -= 1;
      if (qq.activeQuestion.inputs.isNotEmpty) {
        qq.activeQuestion.inputs.removeLast();
      }
    }
  }

  void _moveNext(Level l) {
    final qq = inExamScreen ? l.exam : l.exercise;
    final status = qq.activeFullQuestionStatus();
    if (status == QuestionsStatus.wrong) {
      _doStatusAnimationAtCount = _inputCount;
    }
    if (qq.activeIndex < qq.questions.length - 1) {
      if (qq.activeQuestion.isPartial || status == QuestionsStatus.correct) {
        if (!qq.activeQuestion.isPartial) {  // for partial questions, we have already scrolled to the end of the group
          _doScrollAtCount = _inputCount;
        }
        qq.activeIndex += 1;
      }
    }
    if (inExamScreen && activeLevel <= levels.length - 1 && l.isSolved()) {
      _doScrollAtCount = _inputCount;
      if (activeLevel == levels.length - 1) {
        levelsUnlocked = levels.length;  // i.e. larger than last level, signalling the game is finished
      } else { // activeLevel < levels.length - 1
        activeLevel += 1;
        if (activeLevel > levelsUnlocked) {
          levelsUnlocked = activeLevel;
        }
      }
    }
  }

  void levelTapped(int questionIdx, {required bool inExam, int levelIdx = 0}) {
    _inputCount++;
    if (inExam) {
      activeLevel = levelIdx;
      levels[activeLevel].exam.activeIndex = questionIdx;
    } else {
      levels[activeLevel].exercise.activeIndex = questionIdx;
    }
    notifyListeners();
  }

  void pushLevel(int levelIdx) {
    if (inExamScreen) {
      _inputCount++;
      _activeLevelStack.add(levelIdx);
      levels[activeLevel].clicked = true;
      // we do not notify listeners here to avoid flicker, as the screen is replaced by LevelScreen anyway
    }
  }
  void popLevel() {
    if (!inExamScreen) {
      _inputCount++;
      final last = _activeLevelStack.removeLast();
      if (last == _activeLevelStack.last) {
        // To avoid unnecessary jumps, we only scroll to the end of the questions
        // when returning from the level that is also currently selected
        // (e.g. when the exam questions of the first levels are made visible)
        _doJumpAtCount = _inputCount;
      }
      _doRedrawAtCount = _inputCount;  // redraw all exams, so that in particular the first levels become visible when they are uncovered (see regression tests)
      notifyListeners(); // to notify about change of active level
    }
  }

  void popSettings() {
    // This method is needed as a workaround for an issue introduced with flutter 3.3.0:
    // When the theme changes, the exam questions do not redraw anymore,
    // so we force a redraw by notifying about a game change.
    _inputCount++;
    _doRedrawAtCount = _inputCount;  // this allows more lazy redrawing of exams (using selectors) whenever global settings are not involved
    notifyListeners();
  }

  Future<void> recomputeExamsState() async {
    // we store and load the id instead of the index to handle new levels
    // inserted before the currently unlocked level
    final levelId = await db.loadKeyValue(levelsUnlockedKey);
    for (var i = 0; i < levels.length; i++) {
      Level l = levels[i];
      // restore activeExamQuestion
      for (var j = 0; j < l.exam.questions.length; j++) {
        l.exam.activeIndex = j;
        if (l.exam.activeQuestion.status() == QuestionsStatus.partial) {
          break;
        }
      }
      // restore unlocked and clicked status
      if (l.id == levelId) {
        levelsUnlocked = i;
        if (i == levels.length - 1 && l.isSolved()) {
          levelsUnlocked = levels.length;  // game is finished
        }
        if (!l.clicked && l.exercise.questions.any((q) => q.inputs.isNotEmpty)) {
          l.clicked = true;  // this avoids unnecessary arrow animation after relaunch
        }
        // The following sets cursor to highest unlocked level (also makes autoscroll after relaunch work for first levels when exam is made visible).
        // (automatically jumping the scrollable ListView to highest unlocked level at launch would be more difficult to implement though,
        // since only the visible part of the list is rendered)
        activeLevel = i;
        break;
      }
    }
  }

  Future<void> storeLevelsUnlocked() {
    final levelId = levels[levelsUnlocked < levels.length ? levelsUnlocked : levels.length - 1].id;
    return db.storeKeyValue(levelsUnlockedKey, levelId);
  }

  Future<void> resetProgress() async {
    levelsUnlocked = 0;
    await storeLevelsUnlocked();
    await db.deleteAnswers(levels);
  }

  Future<void> loadGameState() async {
    // initialization of state from database (to be called once for initialization)
    final answers = await db.loadAnswers(levels);
    for (final level in levels) {
      for (final question in level.exercise.questions.followedBy(level.exam.questions)) {
        final answer = answers[question.fullId(level)];
        if (answer != null) {
          question.updateInputs(question.unstringifyInputs(answer));
        }
      }
    }
    await recomputeExamsState();
  }

  static Future<Game> initializedGame(DatabaseWrapper db, {required bool loadProgress}) async {
    final game = Game(db);
    if (loadProgress) {
      await game.loadGameState();
    }
    return game;
  }
}
