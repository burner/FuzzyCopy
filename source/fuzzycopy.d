module fuzzycopy;

void fuzzyCP(F,T)(ref F from, ref T to) {
	import std.traits : hasMember, isImplicitlyConvertible;
	foreach(mem; __traits(allMembers, F)) {
		alias FromType = typeof(__traits(getMember, to, mem));

		// check if to has a value of the same name
		static if(hasMember!(T, mem)) {
			alias ToType = typeof(__traits(getMember, to, mem));

			static if(is(FromType == struct) && is(ToType == struct)) {
				fuzzyCP(__traits(getMember, from, mem), __traits(getMember, to, mem));
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
