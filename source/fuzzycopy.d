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
	Fuzzy,
	FromAll,
	ToAll,
	Both
}

void fuzzyCP(F,T, FuzzyCP FC = FuzzyCP.Fuzzy)(auto ref F from, auto ref T target) {
	import std.traits : hasMember, isImplicitlyConvertible, isFunction;
	import std.format : format;
	static foreach(mem; __traits(allMembers, typeof(from))) {{
		// we can not copy function so don't try
		static if(mem != "this" && !isFunction!(mixin(format("F.%s", mem)))) {
			alias FromType = typeof(__traits(getMember, from, mem));
			//pragma(msg, mem ~ " " ~ FromType.stringof);

			// check if target has a value of the same name
			static if(hasMember!(T, mem)) {
				static import std.conv;
				alias ToType = typeof(__traits(getMember, target, mem));

				// recursive if it is a struct
				static if(is(FromType == struct) && is(ToType == struct)) {
					fuzzyCP!(FromType,ToType,FC)(
							__traits(getMember, from, mem), 
							__traits(getMember, target, mem)
						);
				// assign if it is assignable
				} else  static if(isImplicitlyConvertible!(FromType,ToType)) {
					__traits(getMember, target, mem) = std.conv.to!(ToType)(
							__traits(getMember, from, mem)
						);
				} else  static if(canBeConvertedWithTo!(FromType,ToType)) {
					__traits(getMember, target, mem) = std.conv.to!(ToType)(
							__traits(getMember, from, mem)
						);
				} else static if(FC == FuzzyCP.Both || FC == FuzzyCP.FromAll) {
					import std.format : format;
					static assert(false, format(
						"fuzzyCP is using '%s' Mode and From '%s' and To '%s' have" 
						~ " a member '%s' but From.%s can not be converted target "
						~ "To.%s",
						FC, F.stringof, T.stringof, mem, FromType.stringof, 
						ToType.stringof));
				}
			// for FromAll and Both To needs a member
			} else static if(FC == FuzzyCP.Both || FC == FuzzyCP.FromAll) {
				import std.format : format;
				static assert(false, format(
					"fuzzyCP is using %s Mode and %s has no member named %s",
					FC, T.stringof, mem));
			}
		}
	}}
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

unittest {
	struct Foo {
		int a = 99;
		int b = 77;

		int fun2() {
			return b;
		}
	}

	struct Bar {
		Foo foo;
		string s = "hello";
		string fun() {
			return s;
		}
	}

	struct NotFoo {
		byte a;
		ushort b;
	}

	struct NotBar {
		NotFoo foo;
		string s;
	}

	Bar bar;
	NotBar nBar;

	fuzzyCP!(Bar,NotBar,FuzzyCP.Both)(bar, nBar);

	assert(nBar.foo.a == 99);
	assert(nBar.foo.b == 77);
	assert(nBar.s == "hello");
}

unittest {
	struct Foo {
		long l = 126;
	}

	struct Bar {
		byte l;
	}

	Foo f;
	Bar b;

	fuzzyCP(f, b);
	assert(b.l == 126);
}
