module dud.pkgdescription.sdl;

import std.algorithm.iteration : map, each, filter, uniq, splitter, joiner;
import std.algorithm.searching : any, canFind;
import std.algorithm.sorting : sort;
import std.array : array, back, empty, front, appender, popFront;
import std.conv : to;
import std.exception : enforce;
import std.format : format, formattedWrite;
import std.range : tee;
import std.stdio;
import std.traits : FieldNameTuple;
import std.typecons : nullable, Nullable;

import dud.pkgdescription.exception;
import dud.pkgdescription.outpututils;
import dud.pkgdescription.udas;
import dud.pkgdescription;
import dud.semver : SemVer;

import dud.sdlang;

@safe:

//
// PackageDescription
//

PackageDescription sdlToPackageDescription(string sdl) @safe {
	auto lex = Lexer(sdl);
	auto parser = Parser(lex);
	Root jv = parser.parseRoot();
	PackageDescription ret;
	sGetPackageDescription(tags(jv), "dub.sdl", ret);
	return ret;
}

void sGetPackageDescription(TagAccessor ts, string key,
		ref PackageDescription ret) @safe
{
	foreach(Tag t; ts) {
		string id = t.fullIdentifier();
		sw: switch(id) {
			static foreach(mem; FieldNameTuple!PackageDescription) {{
				enum Mem = SDLName!mem;
				alias get = SDLGet!mem;
				case Mem:
					get(t, Mem, __traits(getMember, ret, mem));
					break sw;
			}}
			default:
				throw new KeyNotHandled(
					format("The sdl dud format does not know a key '%s'.", id)
				);
		}
	}
}

void packageDescriptionsToS(Out)(auto ref Out o, string key,
		PackageDescription[] pkgs, const size_t indent)
{
	pkgs.each!(it => packageDescriptionToS(o, it.name, it, indent + 1));
}

void packageDescriptionToS(Out)(auto ref Out o, string key,
		PackageDescription pkg, const size_t indent)
{
	static foreach(mem; FieldNameTuple!PackageDescription) {{
		enum Mem = SDLName!mem;
		alias put = SDLPut!mem;
		alias MemType = typeof(__traits(getMember, PackageDescription, mem));
		static if(is(MemType : Nullable!Args, Args...)) {
			if(!__traits(getMember, pkg, mem).isNull) {
				put(o, Mem, __traits(getMember, pkg, mem).get(), indent);
			}
		} else {
			put(o, Mem, __traits(getMember, pkg, mem), indent);
		}
	}}
}

void configurationsToS(Out)(auto ref Out o, string key,
		PackageDescription[] pkgs, const size_t indent)
{
	pkgs.each!(pkg => configurationToS(o, key, pkg, indent));
}

void configurationToS(Out)(auto ref Out o, string key,
		PackageDescription pkg, const size_t indent)
{
	formattedWrite(o, "configuration \"%s\" {\n", pkg.name);
	packageDescriptionToS(o, pkg.name, pkg, indent + 1);
	formattedWrite(o, "}\n");
}

//
// Platform
//

void sGetPlatform(AttributeAccessor aa, ref Platform[] pls) {
	Platform[] tmp = aa
		.filter!(a => a.identifier() == "platform")
		.tee!(a => typeCheck(a.value, [ ValueType.str ]))
		.map!(a => a.value.value.get!string())
		.map!(s => s.splitter("-"))
		.joiner
		.map!(s => to!Platform(s))
		.array
		~ pls;

	pls = tmp.sort.uniq.array;
}

void sGetPlatforms(Tag t, string key, ref Platform[] ret) {
	auto vals = t.values();
	enforce!EmptyInput(!vals.empty,
		"The platforms must not by empty");
	ret = vals
		.tee!(val => typeCheck(val, [ ValueType.str ]))
		.map!(val => val.value.get!string())
		.map!(s => s.splitter("-"))
		.joiner
		.map!(s => to!Platform(s))
		.array
		.sort
		.uniq
		.array;

	enforce!UnexpectedInput(t.attributes().empty,
		"No attributes expected for platforms key");
}

void platformsToS(Out)(auto ref Out o, string key, Platform[] plts,
		const size_t indent)
{
	if(!plts.empty) {
		formatIndent(o, indent, "platforms %-(\"%s\"%| %)\n",
			plts.map!(plt => to!string(plt)));
	}
}

//
// Strings, StringsPlatform
//

void sGetStringsPlatform(Tag t, string key, ref Strings ret) {
	StringsPlatform tmp;
	sGetStrings(t.values(), key, tmp.strs);
	sGetPlatform(t.attributes(), tmp.platforms);
	checkEmptyAttributes(t, key, [ "platform" ]);
	ret.platforms ~= tmp;
}

void stringsPlatformToS(Out)(auto ref Out o, string key, Strings value,
		const size_t indent)
{
	value.platforms.each!(s =>
		formatIndent(o, indent,
			s.strs.any!containsEscapable
				? "%s %-(`%s`%| %) %(platform=%s %)\n"
				: "%s %(%s %) %(platform=%s %)\n",
			key,
			s.strs.map!(s => s),
			s.platforms.map!(p => to!string(p)))
	);
}

//
// String, StringPlatform
//

void sGetStringPlatform(Tag t, string key, ref String ret) {
	StringPlatform tmp;
	sGetString(t, key, tmp.str, [ "platform"] );
	sGetPlatform(t.attributes(), tmp.platforms);
	ret.platforms ~= tmp;
}

void stringPlatformToS(Out)(auto ref Out o, string key, String value,
		const size_t indent)
{
	value.platforms.each!(s =>
		formatIndent(o, indent,
			s.str.containsEscapable
				? "%s `%s` %(platform=%s %)\n"
				: "%s \"%s\" %(platform=%s %)\n",
			key,
			s.str,
			s.platforms.map!(p => to!string(p)))
	);
}

//
// string
//

void sGetString(Tag t, string key, ref string ret,
		string[] allowedAttributes = string[].init)
{
	sGetString(t.values(), key, ret);
	checkEmptyAttributes(t, key, allowedAttributes);
}

void sGetString(ValueRange v, string key, ref string ret) {
	Token f = expectedSingleValue(v);
	typeCheck(f, [ ValueType.str ]);
	ret = f.value.get!string();
}

void stringToSName(Out)(auto ref Out o, string key, string value,
		const size_t indent)
{
	if(!value.empty) {
		formatIndent(o, indent, "%s \"%s\"\n", key, value);
	}
}

void stringToS(Out)(auto ref Out o, string key, string value,
		const size_t indent)
{
	if(!value.empty) {
		if(value.containsEscapable()) {
			formatIndent(o, indent, "%s `%s`\n", key, value);
		} else {
			formatIndent(o, indent, "%s \"%s\"\n", key, value);
		}
	}
}

//
// string[]
//

void sGetStrings(Tag t, string key, ref string[] ret) {
	sGetStrings(t.values(), key, ret);
}

void sGetStrings(ValueRange v, string key, ref string[] ret) {
	enforce!EmptyInput(!v.empty, format("Can not get elements of '%s'", key));
	v
		.tee!(it => typeCheck(it, [ ValueType.str ]))
		.each!(it => ret ~= it.value.get!string());
}

void stringsToS(Out)(auto ref Out o, string key, string[] values,
		const size_t indent)
{
	if(!values.empty) {
		formatIndent(o, indent,
			values.any!containsEscapable
				? "%s %-(`%s`%| %)\n"
				: "%s %(%s %)\n",
			key,
			values.map!(s => s));
	}
}

//
// SubPackage
//

void sGetSubPackage(Tag t, string key, ref SubPackage[] ret) {
	ValueRange vr = t.values();
	SubPackage tmp;
	if(!vr.empty) {
		sGetPath(t, key, tmp.path);
	} else {
		PackageDescription iTmp;
		sGetPackageDescription(tags(t.oc), key, iTmp);
		tmp.inlinePkg = nullable(iTmp);
	}
	ret ~= tmp;
}

void subPackagesToS(Out)(auto ref Out o, string key, SubPackage[] sps,
		const size_t indent)
{
	foreach(sp; sps) {
		if(!sp.path.platforms.empty) {
			sp.path.platforms.each!(p =>
				formatIndent(o, indent, "subPackage \"%s\" %(platform=%s %)\n",
					p.path.path, p.platforms.map!(it => to!string(it)))
			);
		} else if(!sp.inlinePkg.isNull()) {
			formatIndent(o, indent, "subPackage {\n");
			packageDescriptionToS(o, "SubPackage", sp.inlinePkg.get(),
					indent + 1);
			formatIndent(o, indent, "}\n");
		} else {
			assert(false, "SubPackage without a path or inlinePkg");
		}
	}
}

//
// SemVer
//

void sGetSemVer(Tag t, string key, ref SemVer ret) {
	sGetSemVer(t.values(), key, ret);
	checkEmptyAttributes(t, key, []);
}

void sGetSemVer(ValueRange v, string key, ref SemVer ver) {
	string s;
	sGetString(v, "SemVer", s);
	ver = nullable(SemVer(s));
}

void semVerToS(Out)(auto ref Out o, string key, SemVer sv,
		const size_t indent)
{
	string s = sv.toString();
	if(!s.empty) {
		formatIndent(o, indent, "%s \"%s\"\n", key, s);
	}
}

//
// BuildOption
//

void sGetBuildOptions(Tag t, string key, ref BuildOptions ret) {
	string[] s;
	sGetStrings(t, key, s);
	enforce!EmptyInput(!s.empty, format("'%s' must not be empty", key));
	BuildOption[] bos = s.map!(it => to!BuildOption(it)).array;

	Platform[] plts;
	sGetPlatform(t.attributes(), plts);
	if(!plts.empty) {
		immutable(Platform[]) iPlts = plts.idup;
		ret.platforms[iPlts] = bos;
	} else {
		ret.unspecifiedPlatform = bos;
	}
}

void buildOptionsToS(Out)(auto ref Out o, string key, BuildOptions bos,
		const size_t indent)
{
	if(!bos.unspecifiedPlatform.empty) {
		formatIndent(o, indent, "%s %(%s %)\n", key,
				bos.unspecifiedPlatform.map!(bo => to!string(bo)));
	}

	foreach(plt, bo; bos.platforms) {
		formatIndent(o, indent, "%s %(%s %) %(platform=%s %)\n", key,
				bo.map!(bo => to!string(bo)),
				plt.map!(p => to!string(p)));
	}
}

//
// TargetType
//

void sGetTargetType(Tag t, string key, ref TargetType ret) {
	sGetTargetType(t.values(), key, ret);
}

void sGetTargetType(ValueRange v, string key, ref TargetType p) {
	string s;
	sGetString(v, "TargetType", s);
	p = to!TargetType(s);
}

void targetTypeToS(Out)(auto ref Out o, string key, TargetType p,
		const size_t indent)
{
	if(p != TargetType.autodetect) {
		formatIndent(o, indent, "%s \"%s\"\n", key, p);
	}
}

//
// BuildRequirements
//

void sGetBuildRequirements(Tag t, string key, ref BuildRequirement[] ret) {
	sGetBuildRequirements(t.values(), key, ret);
}

void sGetBuildRequirements(ValueRange v, string key, ref BuildRequirement[] p) {
	enforce!EmptyInput(!v.empty, "Can not get element of empty range");
	v.map!(it => it.value.get!string()).each!(s => p ~= to!BuildRequirement(s));
}

void buildRequirementsToS(Out)(auto ref Out o, string key,
		BuildRequirement[] ps, const size_t indent)
{
	if(!ps.empty) {
		formatIndent(o, indent, "%s %(%s %)\n", key,
			ps.map!(it => to!string(it)));
	}
}

void sGetSubConfig(Tag t, string key, ref SubConfigs ret) {
	string[] s;
	sGetStrings(t, key, s);
	if(s.length != 2) {
		throw new UnexpectedInput(format("Expected two strings not '%s'"),
			Location("", t.id.cur.line, t.id.cur.column));
	}
	Platform[] plts;
	sGetPlatform(t.attributes(), plts);
	immutable(Platform[]) iPlts = plts.idup;

	if(iPlts.empty) {
		if(s[0] in ret.unspecifiedPlatform) {
			throw new ConflictingInput(
				format("Subconfig for '%s' already specified", s[0]),
				Location("", t.id.cur.line, t.id.cur.column));
		}
		ret.unspecifiedPlatform[s[0]] = s[1];
	} else {
		string[string] tmp;
		tmp[s[0]] = s[1];

		if(iPlts in ret.configs && s[0] in ret.configs[iPlts]) {
			throw new ConflictingInput(
				format("Subconfig for '%s' already specified", s[0]),
				Location("", t.id.cur.line, t.id.cur.column));
		}
		ret.configs[iPlts] = tmp;
	}
}

void subConfigsToS(Out)(auto ref Out o, string key,
		SubConfigs scf, const size_t indent)
{
	scf.unspecifiedPlatform.byKeyValue()
		.each!(sc =>
			formatIndent(o, indent, "subConfiguration \"%s\" \"%s\"\n",
				sc.key, sc.value)
		);
	scf.configs.byKeyValue()
		.each!(plt =>
				plt.value.byKeyValue().each!(sc =>
					formatIndent(o, indent,
						"subConfiguration \"%s\" \"%s\" %(platform=%s %)\n",
						sc.key, sc.value, plt.key.map!(it => to!string(it)))
				)
			);

}

//
// paths
//

void sGetPaths(Tag t, string key, ref Paths ret) {
	auto v = t.values();
	enforce!EmptyInput(!v.empty, format("Can not get elements of '%s'", key));
	PathsPlatform pp;
	pp.paths = v
		.tee!(it => typeCheck(it, [ ValueType.str ]))
		.map!(it => it.value.get!string())
		.map!(s => UnprocessedPath(s))
		.array;
	sGetPlatform(t.attributes(), pp.platforms);
	ret.platforms ~= pp;
}

void pathsToS(Out)(auto ref Out o, string key, Paths ps,
		const size_t indent)
{
	ps.platforms.each!(p =>
		formatIndent(o, indent, "%s %(%s %) %(platform=%s %)\n",
			key, p.paths.map!(it => it.path),
			p.platforms.map!(it => to!string(it)))
	);
}

//
// path
//

void sGetPath(Tag t, string key, ref Path ret) {
	auto v = t.values();
	Token f = expectedSingleValue(v);
	typeCheck(f, [ ValueType.str ]);
	string s = f.value.get!string();
	PathPlatform pp;
	pp.path = UnprocessedPath(s);
	sGetPlatform(t.attributes(), pp.platforms);
	ret.platforms ~= pp;
}

void pathToS(Out)(auto ref Out o, string key, Path p,
		const size_t indent)
{
	p.platforms.each!(plt =>
		formatIndent(o, indent,
			(plt.path.path.containsEscapable()
				? "%s `%s` %(platform=%s %)\n"
				: "%s \"%s\" %(platform=%s %)\n"),
			key,
			plt.path.path, plt.platforms.map!(it => to!string(it)))
	);
}

//
// BuildTypes
//

void sGetBuildTypes(Tag t, string key, ref BuildType[] bts) {
	string buildTypesName;
	sGetString(t, "name", buildTypesName, [ "platform" ]);

	Platform[] plts;
	sGetPlatform(t.attributes(), plts);

	//PackageDescription* pkgDesc = new PackageDescription;
	PackageDescription pkgDesc;
	sGetPackageDescription(tags(t.oc), "buildTypes", pkgDesc);

	BuildType bt;
	bt.name = buildTypesName;
	bt.platforms = plts;
	bt.pkg = pkgDesc;

	bts ~= bt;
}

void buildTypeToS(Out)(auto ref Out o, string key, ref BuildType bt,
		const size_t indent)
{
	formatIndent(o, indent, "debugType \"%s\" {\n", bt.name);
	packageDescriptionToS(o, "", bt.pkg, indent);
	formatIndent(o, indent, "}\n");
}

void buildTypesToS(Out)(auto ref Out o, string key, ref BuildType[] bts,
		const size_t indent)
{
	bts.each!(bt => buildTypeToS(o, key, bt, indent));
}

//
// PackageDescription
//

void sGetPackageDescriptions(Tag t, string key,
		ref PackageDescription[] ret) @safe
{
	string n;
	sGetString(t, "name", n);
	PackageDescription tmp;
	tmp.name = n;
	sGetPackageDescription(tags(t.oc), "configuration", tmp);
	if(tmp.name != n) {
		throw new UnexpectedInput(format(
			"Configuration names must not be changed in OptChild '%s' => '%s'",
			n, tmp.name),
			Location("", t.id.cur.line, t.id.cur.column)
		);
	}
	ret ~= tmp;
}

//
// Dependencies
//

void sGetDependencies(Tag t, string key, ref Dependency[] ret) {
	sGetDependencies(t.values(), t.attributes(), key, ret);
}

void sGetDependencies(ValueRange v, AttributeAccessor ars, string key,
		ref Dependency[] deps)
{
	import dud.pkgdescription.versionspecifier;
	enforce!EmptyInput(!v.empty,
		format("Can not get Dependencies of an empty range", key));
	string name;
	sGetString(v, key, name);
	Dependency ret;
	sGetPlatform(ars, ret.platforms);
	checkEmptyAttributes(ars, key,
		[ "version", "path", "optional", "default", "platform" ]);
	ret.name = name;
	foreach(Attribute it; ars) {
		switch(it.identifier()) {
			case "version":
				ret.version_ = it
					.value
					.value
					.get!string()
					.parseVersionSpecifier;
				break;
			case "path":
				ret.path = UnprocessedPath(it.value.value.get!string());
				break;
			case "optional":
				ret.optional = it
					.value
					.value
					.get!bool()
					.nullable;
				break;
			case "default":
				ret.default_ = it
					.value
					.value
					.get!bool()
					.nullable;
				break;
			case "platform":
				sGetPlatform(ars, ret.platforms);
				break;
			default:
				throw new Exception(format(
					"Key '%s' is not part of a Dependency declaration",
					it.identifier()));
		}
	}
	deps ~= ret;
}

void dependenciesToS(Out)(auto ref Out o, string key, Dependency[] deps,
		const size_t indent)
{
	foreach(value; deps) {
		formatIndent(o, indent, "dependency \"%s\"", value.name);
		if(!value.version_.isNull()) {
			formattedWrite(o, " version=\"%s\"", value.version_.get().orig);
		}
		if(!value.path.path.empty) {
			formattedWrite(o, " path=\"%s\"", value.path.path);
		}
		if(!value.default_.isNull()) {
			formattedWrite(o, " default=%s", value.default_.get());
		}
		if(!value.optional.isNull()) {
			formattedWrite(o, " optional=%s", value.optional.get());
		}
		formattedWrite(o, " %(platform=%s %)",
			value.platforms.map!(p => to!string(p)));
		formattedWrite(o, "\n");
	}
}

//
// Output Helper
//

private void indent(Out)(auto ref Out o, const size_t indent) {
	foreach(i; 0 .. indent) {
		formattedWrite(o, "\t");
	}
}

private void formatIndent(Out, Args...)(auto ref Out o, const size_t i,
		string str, Args args)
{
	indent(o, i);
	formattedWrite(o, str, args);
}

//
// Helper
//

void typeCheck(const Token got, const ValueType[] exp,
		string filename = __FILE__, size_t line = __LINE__)
{
	if(!canFind(exp, got.value.type)) {
		throw new WrongTypeSDL(
			exp.length == 1
				? format("Expected a Value of type '%s' but got '%s'",
					exp.front, got.value.type)
				: format("Expected a Value of types [%(%s, %)]' but got '%s'",
					exp, got.value.type),
				Location("", got.line, got.column), filename, line
		);
	}
}

Token expectedSingleValue(ValueRange vr, string filename = __FILE__,
		size_t line = __LINE__)
{
	if(vr.empty) {
		throw new SingleElement("ValueRange was incorrectly empty",
			filename, line);
	}
	Token ret = vr.front;
	vr.popFront();
	if(!vr.empty) {
		throw new SingleElement(
			"ValueRange incorrectly contains more than one element",
			Location("", vr.front.line, vr.front.column), filename, line);
	}
	return ret;
}

void checkEmptyAttributes(Tag t, string key, string[] toIgnore) {
	checkEmptyAttributes(t.attributes(), key, toIgnore);
}

void checkEmptyAttributes(AttributeAccessor ars, string key, string[] toIgnore) {
	auto attrs = ars
		.map!(attr => attr.identifier())
		.filter!(s => !canFind(toIgnore, s));
	if(!attrs.empty) {
		throw new UnsupportedAttributes(format(
			"The key '%s' does not support attributes [%(%s, %)]",
				key, attrs));
	}
}