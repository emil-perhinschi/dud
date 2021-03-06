module dud.resolve.confs;

import std.algorithm.searching : all;
import std.array : array, empty;
import std.format : format;
import std.typecons : Flag;

import dud.resolve.positive;
import dud.resolve.conf;
import dud.semver.versionrange;

@safe pure:

struct Confs {
@safe pure:
	Conf[] confs;
	IsPositive isPositive;

	this(const(Conf)[] input) {
		import std.algorithm.iteration : each;
		input.each!(it => this.insert(it));
	}

	Confs dup() const {
		import std.array : array;
		import std.algorithm.iteration : map;
		return Confs(this.confs.map!(it => it.dup).array);
	}

	void insert(const(Conf) c) {
		import std.algorithm.searching : canFind;
		import std.algorithm.sorting : sort;
		immutable all = Conf("", IsPositive.yes);
		if(c != all && !canFind(this.confs, c)) {
			this.confs ~= c.dup();
			this.confs.sort();
		}
		immutable none = Conf("", IsPositive.no);
		if(canFind(this.confs, none)) {
			this.confs = [none.dup()];
		}
	}
}

Confs invert(const(Confs) input) {
	import std.algorithm.iteration : map;
	import std.array : array;
	return Confs(input.confs
			.map!(it => dud.resolve.conf.invert(it))
			.array
		);
}

bool allowsAll(const(Confs) a, const(Confs) b) {
	static import dud.resolve.conf;
	return a.confs
		.all!(aIt =>
				b.confs.all!(bIt => dud.resolve.conf.allowsAll(aIt, bIt)));
}

bool allowsAny(const(Confs) a, const(Confs) b) {
	static import dud.resolve.conf;
	return a.confs
		.all!(aIt =>
				b.confs.all!(bIt => dud.resolve.conf.allowsAny(aIt, bIt)));
}

SetRelation relation(const(Confs) a, const(Confs) b) {
	static import dud.resolve.conf;
	import std.algorithm.iteration : joiner, map;

	SetRelation[] rslt = a.confs
		.map!(aIt =>
				b.confs.map!(bIt => dud.resolve.conf.relation(bIt, aIt)))
		.joiner
		.array;

	if(rslt.all!(it => it == SetRelation.subset)) {
		return SetRelation.subset;
	}

	if(rslt.all!(it =>
				it == SetRelation.subset || it == SetRelation.overlapping))
	{
		return SetRelation.overlapping;
	}

	return SetRelation.disjoint;
}
