module fuzzycopy;

template canBeConvertedWithTo(F,T) {
	import std.traits : isIntegral, isFloatingPoint, isArray;
	import std.range : ElementEncodingType;

	static if(isIntegral!F && isIntegral!T) {
		enum canBeConvertedWithTo = true;
	} else static if(isIntegral!F && isFloatingPoint!T) {
		enum canBeConvertedWithTo = true;
	} else static if(isFloatingPoint!F && isIntegral!T) {
		enum canBeConvertedWithTo = true;
	} else static if(isArray!F && isArray!T) {
		alias FType = ElementEncodingType!F;
		alias TType = ElementEncodingType!T;
		enum canBeConvertedWithTo = canBeConvertedWithTo!(FType,TType);
	} else {
		enum canBeConvertedWithTo = false;
	}
}

unittest {
	static assert(canBeConvertedWithTo!(int,byte));
	static assert(canBeConvertedWithTo!(byte,float));
	static assert(!canBeConvertedWithTo!(string,float));
	static assert(!canBeConvertedWithTo!(int[],float));
	static assert(canBeConvertedWithTo!(int[],float[]));
	static assert(canBeConvertedWithTo!(byte[],double[]));
	static assert(canBeConvertedWithTo!(double[],ubyte[]));
}

enum FuzzyCP {
	Strict,
	Fuzzy
}

void fuzzyCP(F,T)(ref F from, ref T to) {
	import std.traits : hasMember, isImplicitlyConvertible;
	foreach(mem; __traits(allMembers, F)) {
		alias FromType = typeof(__traits(getMember, to, mem));

		// check if to has a value of the same name
		static if(hasMember!(T, mem)) {
			alias ToType = typeof(__traits(getMember, to, mem));

			// recursive if it is a struct
			static if(is(FromType == struct) && is(ToType == struct)) {
				fuzzyCP(__traits(getMember, from, mem), 
						__traits(getMember, to, mem)
					);
			// assign if it is assignable
			} else  static if(isImplicitlyConvertible!(FromType,ToType)) {
				__traits(getMember, to, mem) = __traits(getMember, from, mem);
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
	}

	struct NotFoo {
		long a;
		long b;
	}

	struct NotBar {
		NotFoo foo;
		string s;
	}

	Bar bar;
	NotBar nBar;

	fuzzyCP(bar, nBar);

	assert(nBar.foo.a == 99);
	assert(nBar.foo.b == 77);
	assert(nBar.s == "hello");
}
