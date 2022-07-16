import 'package:test/test.dart';
import 'package:everest/expressions.dart';

void main() {
  test('addition', () {
    final e = Con(3) + Con(7) + Con(100);
    expect(e.toString(), equals('3 + 7 + 100'));
    expect(e.eval({}), equals(110));
    expect(e.eq(Con(110)).str({}), equals('3 + 7 + 100 = 110'));
  });

  test('various expression operations', () {
    final e = -Con(3.0) * Con(4.0) + Con(14.0) / Con(7.0) - Con(1.0) + Con(3.0).square();
    expect(e.toString(), equals('-3.0 * 4.0 + 14.0 / 7.0 - 1.0 + 3.0²'));
    expect(e.eval({}), equals(-2.0));
  });

  test('variables', () {
    Var<int> y = Var(), z = Var();
    final e = Con(3) + Con(4) * y + z;
    final vars = {y: 2, z: 5};
    expect(e.toString(), equals('3 + 4 * ? + ?'));
    expect(e.str(vars), equals('3 + 4 * 2 + 5'));
    expect(e.str({z: 2, y: 5}), equals('3 + 4 * 5 + 2'));
    expect(e.eval(vars), equals(16));
    expect(() => e.eval({}), throwsA(isA<UnsupportedError>()));
  });

  test('eq', () {
    final e = Con(G.F(2,3)) * Con(G.F(2,5)) * Con(G.F(6,4)) * Con(G.F(1,5));
    expect(e.eq(Con(G.F(1,2))).eval({}), equals(true));
    expect(e.eq(Con(G.F(5,8))).eval({}), equals(false));
    expect(e.eq(Con(G.F(6,7))).eval({}), equals(false));
    expect(e.eq(Con(G.F(0,0))).eval({}), equals(false));
    expect(e.eq(Con(G.F(1,0))).eval({}), equals(false));
    expect(e.eq(Con(G.F(0,1))).eval({}), equals(false));
  });

  final testElems = [G.F(1,2), G.F(3,4), G.F(5,7), G.F(9,2)];

  test('pow', () {
    for (final dynamic a in testElems.cast<dynamic>().followedBy([F(3), F(4)])) {
      for (final n in [1,2,3,4,5,6,7,8,9,10]) {
        expect(a.pow(n), equals(List.filled(n-1, a).fold(a, (dynamic b, c) => b * c)));
      }
    }
  });

  test('div', () {
    for (final a in testElems) {
      expect(a / a, equals(G.F(1,0)));
    }
    for (final a in [F(3), F(4), F(5), F(6)]) {
      expect(a / a, equals(F(1)));
    }
  });

  test('operations on G', () {
    expect(-G.F(1,2) + G.F(3,4) * G.F(5,6) / G.F(7,8) - G.F(9,10).pow(2), equals(G.F(-1,6)));
  });

  test('dot', () {
    expect((dot(3,4) * dot(5,8) * dot(6,5) * dot(7,X)).eq(dot(4, 2)).eval({}), equals(true));
  });

  test('parse', () {
    expect(F.parse('X'), equals(X.eval({})));
    expect(F.parse('-1'), equals(F(-1)));
    expect(F.parse('123'), equals(F(123)));
  });
}
