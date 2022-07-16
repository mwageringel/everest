// expression algebra with variables, constants and unary and binary operations.

A _evalMult<A>(A left, A right) => (left as dynamic) * right;

typedef EvalContext = Map<Var<dynamic>, dynamic>;  // all our variables will have type parameter F

abstract class Expression<A> {
  String str(EvalContext vars);
  A eval(EvalContext vars);
  String evalString(EvalContext vars) => '[${str(vars)}] = ${eval(vars)}';  // for debugging
  @override toString() => str({});

  Expression<bool>      eq(Expression<A> other) => Bin(this, other, str: (s, t) => '$s = $t', eval: (a, b) => (a as dynamic).pow(1331) == (b as dynamic).pow(p));
  Expression<A> operator +(Expression<A> other) => Bin(this, other, str: (s, t) => '$s + $t', eval: (a, b) => (a as dynamic) + b);
  Expression<A> operator -(Expression<A> other) => Bin(this, other, str: (s, t) => '$s - $t', eval: (a, b) => (a as dynamic) - b);
  Expression<A> operator *(Expression<A> other) => Bin(this, other, str: (s, t) => '$s * $t', eval: _evalMult);
  Expression<A> operator /(Expression<A> other) => Bin(this, other, str: (s, t) => '$s / $t', eval: (a, b) => (a as dynamic) / b);
  Expression<A> operator -() => Unary(this, str: (s) => '-$s', eval: (a) => -(a as dynamic));
  Expression<A> square() => Unary(this, str: (s) => '$s²', eval: (A a) => _evalMult(a, a));
  // Expression<A> paren() => Unary(this, str: (s) => '($s)', eval: (A a) => a);  // not needed yet
}

class Var<A> extends Expression<A> {
  @override str(vars) => vars[this]?.toString() ?? '?';
  @override eval(vars) {
    final a = vars[this];
    if (a == null) {
      throw UnsupportedError('can only evaluate variables in vars context');
    } else {
      return a;
    }
  }
}

class Con<A> extends Expression<A> {
  final A con;
  final String? _str;
  Con(this.con, {String? str}) : _str = str;
  @override str(vars) => _str ?? con.toString();
  @override eval(vars) => con;
}

class Bin<A, B> extends Expression<B> {
  final Expression<A> left, right;
  final B Function(A, A) _eval;
  final String Function(String, String) _str;
  Bin(this.left, this.right, {required B Function(A, A) eval, required String Function(String, String) str}):
    _eval = eval, _str = str;
  @override str(vars) => _str(left.str(vars), right.str(vars));
  @override eval(vars) => _eval(left.eval(vars), right.eval(vars));
}

class Unary<A, B> extends Expression<B> {
  final Expression<A> operand;
  final B Function(A) _eval;
  final String Function(String) _str;
  Unary(this.operand, {required B Function(A) eval, required String Function(String) str}):
    _eval = eval, _str = str;
  @override str(vars) => _str(operand.str(vars));
  @override eval(vars) => _eval(operand.eval(vars));
}

A _pow<A>(A x, int n) {
  if (n <= 0) {
    throw UnsupportedError("exponent must be positive");
  } else {
    A? res;  // iterated squaring without 1
    while (n > 0) {
      if (n.isOdd) {
        res = res == null ? x : _evalMult(res, x);
      }
      x = _evalMult(x , x);
      n = n ~/ 2;
    }
    return res as A;  // res is never null
  }
}

const int p = 11;
class F {
  final int _u;
  F._mkF(this._u);
  static final List<F> elems = List.unmodifiable(List.generate(p, F._mkF));
  factory F(int u) => elems[u % p];
  factory F.parse(String s) => s == 'X' ? X.con : F(int.parse(s));
  @override toString() => _u.toString();
  @override operator ==(other) => other is F ? _u == other._u : false;
  @override int get hashCode => _u.hashCode;
  F operator +(F other) => F(_u + other._u);
  F operator *(F other) => F(_u * other._u);
  F operator -(F other) => F(_u - other._u);
  F operator -() => F(-_u);
  F pow(int exponent) => F(_u.modPow(exponent, p));
  F operator /(F other) => this * other.pow(p-2);  // ignoring 0
}

class G {
  final F a, b;
  G(this.a, this.b);
  factory G.F(int a, int b) => G(F(a), F(b));
  factory G.fromF(F a) => G(a, F(0));
  @override toString() => '($a,$b)';
  @override operator ==(other) => other is G ? a == other.a && b == other.b : false;
  @override int get hashCode => b.hashCode * p + a.hashCode;
  G operator +(G other) => G(a + other.a, b + other.b);
  G operator *(G other) {
    final c = other.a, d = other.b;
    return G(a*c + F(9)*b*d, b*c + (F(4)*b + a)*d);
  }
  G operator -() => G(-a, -b);
  G operator -(G other) => this + -other;
  G pow(int exponent) => _pow(this, exponent);
  G operator /(G other) => this * other.pow(119);  // ignoring 0 (so `other` must not be user input)
}

final X = Con(F(7).pow(35), str: 'X');

Expression<F> C(int u) => Con(F(u));

Expression<F> _toExprF(x) {
  if (x is Expression) {
    return x as Expression<F>;
  } else if (x is F) {
    return Con(x);
  } else if (x is int) {
    return Con(F(x));
  } else {
    throw UnsupportedError("$x not viewable as Expression<F>");
  }
}

final G _s = G.F(3, 3);

Expression<G> dot(left, right) {
  return Bin<F, G>(_toExprF(left), _toExprF(right),
    eval: (a, b) => G(b + F(6)*a, a + b) * _s,
    str: (s, t) => '$s.$t',
  );
}
