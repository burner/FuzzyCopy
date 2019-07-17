module fuzzycopy;

import std.algorithm.iteration : map;
import std.array : array, empty;
import std.conv : to;
import std.format : format;
import std.range : ElementEncodingType;
import std.traits : isFunction, hasMember, isImplicitlyConvertible,
	isIntegral, isFloatingPoint, isArray, isSomeString, FieldNameTuple;
import std.typecons : Nullable, nullable;
import std.stdio;

template isNullable(T) {
	enum isNullable = is(T : Nullable!F, F);
}

template Type(T) {
	static if(is(T : Nullable!F, F)) {
		alias Type = F;
	} else {
		alias Type = T;
	}
}

template extractBaseType(T) {
	static if(is(T : Nullable!F, F)) {
		alias extractBaseType = .extractBaseType!F;
	} else static if(isArray!T && !isSomeString!T) {
		alias extractBaseType = .extractBaseType!(ElementEncodingType!T);
	} else {
		alias extractBaseType = T;
	}
}

unittest {
	static assert(is(extractBaseType!float == float));
	static assert(is(extractBaseType!(Nullable!float) == float));
	static assert(is(extractBaseType!(Nullable!(float[])) == float));
	static assert(is(extractBaseType!(Nullable!(Nullable!float[])) == float));
	static assert(is(extractBaseType!string == string));
	static assert(is(extractBaseType!(Nullable!string) == string));
	static assert(is(extractBaseType!(Nullable!(string[])) == string));
	static assert(is(extractBaseType!(Nullable!(Nullable!string[])) == string));
}

template arrayDepth(T) {
	static if(isArray!T && !isSomeString!T) {
		enum arrayDepth = 1 + .arrayDepth!(ElementEncodingType!T);
	} else static if(is(T : Nullable!F, F)) {
		enum arrayDepth = .arrayDepth!F;
	} else {
		enum arrayDepth = 0;
	}
}

unittest {
	static assert(arrayDepth!(int[]) == 1);
	static assert(arrayDepth!(int) == 0);
	static assert(arrayDepth!(int[][]) == 2);
	static assert(arrayDepth!(Nullable!(int[])[]) == 2);
}

template StripNullable(T) {
	static if(is(T : Nullable!F, F)) {
		alias StripNullable = .StripNullable!F;
	} else static if(isArray!T && !isSomeString!T) {
		alias StripNullable = .StripNullable!(ElementEncodingType!T)[];
	} else {
		alias StripNullable = T;
	}
}

unittest {
	static assert(is(StripNullable!(int) == int));
	static assert(is(StripNullable!(int[]) == int[]));
	static assert(is(StripNullable!(Nullable!int[]) == int[]));
	static assert(is(StripNullable!(Nullable!(int[])) == int[]));
	static assert(is(StripNullable!(Nullable!(Nullable!int[])) == int[]));

	struct Foo {
	}
	static assert(is(StripNullable!(Foo) == Foo));
	static assert(is(StripNullable!(Foo[]) == Foo[]));
	static assert(is(StripNullable!(Nullable!Foo[]) == Foo[]));
	static assert(is(StripNullable!(Nullable!(Foo[])) == Foo[]));
	static assert(is(StripNullable!(Nullable!(Nullable!Foo[])) == Foo[]));
}

template StripTopNullable(T) {
	static if(is(T : Nullable!F, F)) {
		alias StripTopNullable = F;
	} else {
		alias StripTopNullable = T;
	}
}

unittest {
	static assert(is(StripTopNullable!(int) == int));
	static assert(is(StripTopNullable!(int[]) == int[]));
	static assert(is(StripTopNullable!(Nullable!(int[])) == int[]));
	static assert(is(StripTopNullable!(Nullable!(int[])) == int[]));
	static assert(is(StripTopNullable!(Nullable!(Nullable!int[])) == Nullable!(int)[]));
}

template canBeConvertedWithTo(F,T) {
	alias FT = extractBaseType!F;
	alias TT = extractBaseType!T;
	enum FD = arrayDepth!F;
	enum TD = arrayDepth!T;

	static if(isIntegral!FT && isIntegral!TT && FD == TD && FD == 0) {
		enum canBeConvertedWithTo = true;
	} else static if(isIntegral!FT && isFloatingPoint!TT 
			&& FD == TD && FD == 0) 
	{
		enum canBeConvertedWithTo = true;
	} else static if(isFloatingPoint!FT && isIntegral!TT && FD == TD 
			&& FD == 0) 
	{
		enum canBeConvertedWithTo = true;
	} else static if(isSomeString!FT && isSomeString!TT && FD == TD 
			&& FD == 0) 
	{
		enum canBeConvertedWithTo = true;
	} else {
		enum canBeConvertedWithTo = false;
	}
}

unittest {
	static assert(canBeConvertedWithTo!(int,byte));
	static assert(canBeConvertedWithTo!(byte,float));
	static assert(!canBeConvertedWithTo!(string,float));
	static assert(!canBeConvertedWithTo!(int[],float));
	static assert(!canBeConvertedWithTo!(int[],float[]));
	static assert(!canBeConvertedWithTo!(byte[],double[]));
	static assert(!canBeConvertedWithTo!(double[],ubyte[]));
}

auto getValue(TnN,F,string mem)(ref F f) {
	alias FMem = typeof(__traits(getMember, F, mem));
	enum FiN = isNullable!FMem;

	struct Result {
		Type!FMem value;
		bool isNull;
	}

	Result ret;

	static if(FiN) {
		if(__traits(getMember, f, mem).isNull()) {
			ret.isNull = true;
		} else {
			ret.value = __traits(getMember, f, mem).get();
			ret.isNull = false;
		}
	} else {
		ret.value = __traits(getMember, f, mem);
		ret.isNull = false;
	}
	return ret;
}

auto getValue(T)(auto ref T t) {
	alias TnN = StripTopNullable!T;
	struct Ret {
		TnN value;
		bool isNull;
	}
	Ret ret;

	static if(isNullable!T) {
		if(t.isNull()) {
			ret.isNull = true;
		} else {
			ret.isNull = false;
			ret.value = t.get();
		}
	} else {
		ret.isNull = false;
		ret.value = t;
	}
	return ret;
}

void fuzzyCP(F,T)(auto ref F f, auto ref T t) {
	static if(is(F == T)) {
		t = f;
	} else {
	outer: foreach(mem; FieldNameTuple!F) {
		static if(__traits(hasMember, T, mem)) {
			alias FMem = typeof(__traits(getMember, F, mem));
			alias TMem = typeof(__traits(getMember, T, mem));
			alias FnN = StripNullable!FMem;
			alias TnN = StripNullable!TMem;

			enum FiS = is(FnN == struct);
			enum TiS = is(TnN == struct);

			enum FiN = isNullable!FMem;
			enum TiN = isNullable!TMem;

			enum FiA = isArray!FnN;
			enum TiA = isArray!TnN;

			enum Fd = arrayDepth!FnN;
			enum Td = arrayDepth!TnN;

			static if(FiS && TiS) { // two struct
				fuzzyCP(__traits(getMember, f, mem), 
						__traits(getMember, t, mem)
					);
			} else static if(is(FMem == TMem)) { // same types
				__traits(getMember, t, mem) = __traits(getMember, f, mem);
			} else static if(FiA && TiA && Fd == Td && Fd == 1) {
				alias Tet = ElementEncodingType!(StripTopNullable!(TMem));
				auto arr = getValue!(TnN,F,mem)(f);

				Tet[] tmp;
				if(!arr.isNull) {
					foreach(it; arr.value) {
						auto itV = getValue(it);
						if(!itV.isNull) {
							static if(isNullable!Tet) {
								tmp ~= nullable(itV.value);
							} else {
								tmp ~= itV.value;
							}
						}
					}
				}
				static if(isNullable!(TMem)) {
					if(!tmp.empty) {
						__traits(getMember, t, mem) = nullable(tmp);
					}
				} else {
					if(!tmp.empty) {
						__traits(getMember, t, mem) = tmp;
					}
				}
			} else static if(canBeConvertedWithTo!(FnN,TnN)) { // using to!
				auto val = getValue!(TnN,F,mem)(f);
				if(!val.isNull) {
					static if(TiN) {
						__traits(getMember, t, mem) = nullable(to!TnN(val.value));
					} else {
						//writefln("%s %s", mem, fVal);
						__traits(getMember, t, mem) = to!TMem(val.value);
					}
				}
			}
		}
	}
	}
}

unittest {
	struct Foo {
		int a = 10;
		int b = 20;
	}

	struct Bar {
		int a;
		int b;
	}

	Foo foo;
	assert(foo.a == 10);
	assert(foo.b == 20);

	Bar bar;

	fuzzyCP(foo, bar);

	assert(bar.a == 10);
	assert(bar.b == 20);
}

unittest {
	struct Foo {
		int a = 99;
		int b = 77;
	}

	struct Bar {
		Foo foo;
		string s = "hello";
		wstring r = "world";
	}

	struct NotFoo {
		long a;
		long b;
	}

	struct NotBar {
		NotFoo foo;
		string s;
		dstring r;
	}

	Bar bar;
	NotBar nBar;

	fuzzyCP(bar, nBar);

	assert(nBar.foo.a == 99);
	assert(nBar.foo.b == 77);
	assert(nBar.s == "hello", format("'%s'", nBar.s));
	assert(nBar.r == "world", format("'%s'", nBar.r));
}

unittest {
	struct Foo {
		int a = 99;
		Nullable!int b = 77;
		int c = 66;
	}

	struct NotFoo {
		long a;
		long b;
		Nullable!byte c;
	}

	Foo foo;
	NotFoo nFoo;

	fuzzyCP(foo, nFoo);

	assert(nFoo.a == 99);
	assert(nFoo.b == 77, format("%s", nFoo.b));
	assert(nFoo.c.get() == 66);
}

unittest {
	struct Foo {
		int a = 99;
		Nullable!int b = 77;
		int c = 66;
		int d;
	}

	struct Bar {
		Foo[] foos;
	}

	struct NotFoo {
		long a;
		long b;
		Nullable!byte c;
	}

	struct NotBar {
		Foo[] foos;
	}

	Bar bar;
	bar.foos = [Foo.init, Foo.init];
	NotBar nBar;

	fuzzyCP(bar, nBar);

	assert(nBar.foos.length == 2, format("%s", nBar.foos.length));
}

unittest {
	struct Foo {
		Nullable!(int)[] i;
	}

	struct Bar {
		int[] i;
	}

	Foo f;
	f.i = [nullable(1), nullable(2), Nullable!(int).init];

	Bar b;
	fuzzyCP(f, b);
	assert(b.i.length == 2);
	assert(b.i == [1, 2]);
}

unittest {
	struct Foo {
		Nullable!(int)[] i;
	}

	struct Bar {
		Nullable!(int[]) i;
	}

	Foo f;
	f.i = [nullable(1), nullable(2), Nullable!(int).init];

	Bar b;
	fuzzyCP(f, b);
	assert(!b.i.isNull());
	assert(b.i.get().length == 2);
	assert(b.i.get() == [1, 2]);
}

unittest {
	struct Foo {
		Nullable!(int)[] i;
	}

	struct Bar {
		int[] i;
	}

	Foo f;

	Bar b;
	fuzzyCP(f, b);
	assert(b.i.length == 0);
}

unittest {
	struct Foo {
		Nullable!(Nullable!(int)[]) i;
	}

	struct Bar {
		Nullable!(int[]) i;
	}

	Foo f;
	f.i = [nullable(1), nullable(2), Nullable!(int).init];

	Bar b;
	fuzzyCP(f, b);
	assert(!b.i.isNull());
	assert(b.i.get().length == 2);
	assert(b.i.get() == [1, 2]);
}

template CanBeConverted(F,T) {
	alias FnN = StripTopNullable!F;
	alias TnN = StripTopNullable!T;

	static if(is(FnN == TnN)) {
		enum CanBeConverted = true;
	} else static if(is(FnN == struct) && is(TnN == struct)) {
		enum CanBeConverted = true;
	} else static if(isSomeString!FnN && isSomeString!TnN) {
		enum CanBeConverted = true;
	} else static if(isArray!FnN && isArray!TnN) {
		enum CanBeConverted = .CanBeConverted!(
				ElementEncodingType!FnN,
				ElementEncodingType!TnN);
	} else static if((isIntegral!FnN || isFloatingPoint!FnN)
			|| (isIntegral!TnN || isFloatingPoint!TnN))
	{
		enum CanBeConverted = true;
	} else {
		enum CanBeConverted = false;
	}
}

auto wrap(T,Val)(Val v) {
	static if(is(T : Nullable!F, F)) {
		return nullable(v);
	} else {
		return v;
	}
}

auto nullAccess(V)(V val) {
	struct Ret {

	}
}

T fuzzyTo(T,F)(F f) {
	static if(is(T == F)) {
		return f;
	} else {
	T ret;
	foreach(mem; FieldNameTuple!F) {
		static if(__traits(hasMember, T, mem)) {
			alias FT = typeof(__traits(getMember, F, mem));
			alias TT = typeof(__traits(getMember, T, mem));
			static if(CanBeConverted!(FT, TT)) {
				alias FnN = StripTopNullable!FT;
				auto memVal = getValue(__traits(getMember, f, mem));
				if(memVal.isNull) {
					continue;
				}

				alias TnN = StripTopNullable!TT;

				static if(canBeConvertedWithTo!(FnN,TnN)) {
					__traits(getMember, ret, mem) = wrap!TT(
							to!TnN(memVal.value)
						);
				} else static if(is(FnN == struct)) {
					__traits(getMember, ret, mem) = wrap!TT(
							fuzzyTo!TnN(memVal.value)
						);
				} else static if(isArray!FnN) {
					alias TET = ElementEncodingType!TnN;
					alias TETNN = StripTopNullable!TET;
					TET[] arr;
					foreach(it; memVal.value) {
						auto itVal = getValue(it);
						if(!itVal.isNull) {
							static if(canBeConvertedWithTo!(typeof(itVal.value),TETNN))
							{
								arr ~= wrap!TET(to!TETNN(itVal.value));
							} else {
								arr ~= wrap!TET(fuzzyTo!TETNN(itVal.value));
							}
						}
					}
					static if(isNullable!TT) {
						__traits(getMember, ret, mem) = nullable(arr);
					} else {
						__traits(getMember, ret, mem) = arr;
					}
				}
			}
		}
	}

	return ret;
	}
}

unittest {
	struct F {
		int a = 13;
	}

	struct T {
		byte a;
	}

	F f;
	T t = fuzzyTo!T(f);
	assert(t.a == 13);

	F f2 = fuzzyTo!F(f);
}

unittest {
	struct F {
		int a = 13;
		float[] f = [1,2,3];
	}

	struct T {
		byte a;
		byte[] f;
	}

	F f;
	T t = fuzzyTo!T(f);
	assert(t.a == 13);
	assert(t.f == [1,2,3]);
}

unittest {
	struct F {
		int a = 13;
		Nullable!(float)[] f = [nullable(1.0),nullable(2.0),nullable(3.0)];
	}

	struct T {
		byte a;
		byte[] f;
	}

	F f;
	T t = fuzzyTo!T(f);
	assert(t.a == 13);
	assert(t.f == [1,2,3]);
}

unittest {
	struct F {
		int a = 13;
		Nullable!(float)[] f = [nullable(1.0),nullable(2.0),nullable(3.0)];
	}

	struct T {
		byte a;
		Nullable!(byte)[] f;
	}

	F f;
	T t = fuzzyTo!T(f);
	assert(t.a == 13);
	assert(t.f == [1,2,3]);
}

unittest {
	struct F {
		int a = 13;
		Nullable!(Nullable!(double)[]) f;
	}

	struct T {
		byte a;
		Nullable!(byte)[] f;
	}

	F f;
	f.f = nullable([nullable(1.0),nullable(2.0),nullable(3.0)]);
	T t = fuzzyTo!T(f);
	assert(t.a == 13);
	assert(t.f == [1,2,3]);
}

unittest {
	struct F {
		int a = 13;
		Nullable!(Nullable!(double)[]) f;
	}

	struct T {
		byte a;
		Nullable!(byte[]) f;
	}

	F f;
	f.f = nullable([nullable(1.0),nullable(2.0),nullable(3.0)]);
	T t = fuzzyTo!T(f);
	assert(t.a == 13);
	assert(t.f == [1,2,3]);
}

unittest {
	struct F {
		int a = 13;
		Nullable!(Nullable!(double)[]) f;
	}

	struct T {
		byte a;
		Nullable!(Nullable!byte[]) f;
	}

	F f;
	f.f = nullable([nullable(1.0),Nullable!(double).init, nullable(2.0),nullable(3.0)]);
	T t = fuzzyTo!T(f);
	assert(t.a == 13);
	assert(t.f == [1,2,3]);
}

unittest {
	struct A {
		float a = 10;
	}

	struct F {
		A a;
	}

	struct B {
		int a;
	}

	struct T {
		B a;
	}

	F f;
	T t = fuzzyTo!T(f);
	assert(t.a.a == 10);
}

unittest {
	struct A {
		float a = 10;
	}

	struct F {
		Nullable!A a = nullable(A.init);
	}

	struct B {
		int a;
	}

	struct T {
		B a;
	}

	F f;
	T t = fuzzyTo!T(f);
	assert(t.a.a == 10);
}

unittest {
	struct A {
		Nullable!float a = nullable(10.0);
	}

	struct F {
		Nullable!A a = nullable(A.init);
	}

	struct B {
		int a;
	}

	struct T {
		B a;
	}

	F f;
	T t = fuzzyTo!T(f);
	assert(t.a.a == 10);
}

unittest {
	struct A {
		Nullable!float a = nullable(10.0);
	}

	struct F {
		Nullable!(A[]) a = nullable([A.init, A.init]);
	}

	struct B {
		int a;
	}

	struct T {
		B[] a;
	}

	F f;
	T t = fuzzyTo!T(f);
	assert(t.a.map!(it => it.a).array == [10, 10]);
}

unittest {
	struct A {
		Nullable!float a;
	}

	struct F {
		Nullable!(A[]) a = nullable([A.init, A.init]);
		Nullable!(A[]) b;
	}

	struct B {
		int a;
	}

	struct T {
		B[] a;
		B[] b;
	}

	F f;
	T t = fuzzyTo!T(f);
	assert(t.a.length == 2);
	assert(t.b.empty);
}
