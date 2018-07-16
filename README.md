fuzzyCP
=======

Who knows the problem, you have a struct Foo of form
```D
struct Foo {
	int a = 10;
	int b = 20;
}
```
and need to copy it to a struct Bar of form
```D
struct Bar {
	long a;
	byte b;
}
```

You could copy the field by hands, or use fuzzyCP.
fuzzyCP will copy all members from Foo to Bar where Foo and Bar members have
the same name.

Use it like so:
```D
Foo foo;
assert(foo.a == 10);
assert(foo.b == 20);

Bar bar;

fuzzyCP(foo, bar);

assert(bar.a == 10);
assert(bar.b == 20);
```

By default, fuzzyCP will do a best effort copy of all the members of Foo to
Bar.
That means, if Foo has a member that Bar does not have nothing will happen.
If a member in Foo can be converted with std.conv.to that function will be
used.
