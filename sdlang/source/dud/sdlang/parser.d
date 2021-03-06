module dud.sdlang.parser;

import std.typecons : RefCounted, refCounted;
import std.format : format;
import dud.sdlang.ast;
import dud.sdlang.tokenmodule;

import dud.sdlang.lexer;

import dud.sdlang.exception;

struct Parser {
@safe pure:

	import std.array : appender;

	import std.format : formattedWrite;

	Lexer lex;

	this(Lexer lex) {
		this.lex = lex;
	}

	bool firstRoot() const pure @nogc @safe {
		return this.firstTags()
			 || this.firstTagTerminator()
			 || this.lex.front.type == TokenType.eof;
	}

	Root parseRoot() {
		try {
			return this.parseRootImpl();
		} catch(ParseException e) {
			throw new ParseException(
				"While parsing a Root an Exception was thrown.",
				e, __FILE__, __LINE__
			);
		}
	}

	Root parseRootImpl() {
		string[] subRules;
		subRules = ["T"];
		if(this.firstTags()) {
			Tags tags = this.parseTags();
			subRules = ["T"];
			if(this.lex.front.type == TokenType.eof) {
				this.lex.popFront();

				return new Root(RootEnum.T
					, tags
				);
			}
			auto app = appender!string();
			formattedWrite(app, 
				"In 'Root' found a '%s' while looking for", 
				this.lex.front
			);
			throw new ParseException(app.data,
				__FILE__, __LINE__,
				subRules,
				["eof"]
			);

		} else if(this.firstTagTerminator()) {
			this.parseTagTerminator();
			subRules = ["TT"];
			if(this.firstTags()) {
				Tags tags = this.parseTags();
				subRules = ["TT"];
				if(this.lex.front.type == TokenType.eof) {
					this.lex.popFront();

					return new Root(RootEnum.TT
						, tags
					);
				}
				auto app = appender!string();
				formattedWrite(app, 
					"In 'Root' found a '%s' while looking for", 
					this.lex.front
				);
				throw new ParseException(app.data,
					__FILE__, __LINE__,
					subRules,
					["eof"]
				);

			}
			auto app = appender!string();
			formattedWrite(app, 
				"In 'Root' found a '%s' while looking for", 
				this.lex.front
			);
			throw new ParseException(app.data,
				__FILE__, __LINE__,
				subRules,
				["ident -> Tag","lcurly -> Tag","value -> Tag"]
			);

		} else if(this.lex.front.type == TokenType.eof) {
			this.lex.popFront();

			return new Root(RootEnum.E
			);
		}
		auto app = appender!string();
		formattedWrite(app, 
			"In 'Root' found a '%s' while looking for", 
			this.lex.front
		);
		throw new ParseException(app.data,
			__FILE__, __LINE__,
			subRules,
			["ident -> Tag","lcurly -> Tag","value -> Tag","eol","semicolon","eof"]
		);

	}

	bool firstTags() const pure @nogc @safe {
		return this.firstTag();
	}

	Tags parseTags() {
		try {
			return this.parseTagsImpl();
		} catch(ParseException e) {
			throw new ParseException(
				"While parsing a Tags an Exception was thrown.",
				e, __FILE__, __LINE__
			);
		}
	}

	Tags parseTagsImpl() {
		string[] subRules;
		subRules = ["Tag", "TagFollow"];
		if(this.firstTag()) {
			Tag cur = this.parseTag();
			subRules = ["TagFollow"];
			if(this.firstTags()) {
				Tags follow = this.parseTags();

				return new Tags(TagsEnum.TagFollow
					, cur
					, follow
				);
			}
			return new Tags(TagsEnum.Tag
				, cur
			);
		}
		auto app = appender!string();
		formattedWrite(app, 
			"In 'Tags' found a '%s' while looking for", 
			this.lex.front
		);
		throw new ParseException(app.data,
			__FILE__, __LINE__,
			subRules,
			["ident -> IDFull","lcurly -> OptChild","value -> Values"]
		);

	}

	bool firstTag() const pure @nogc @safe {
		return this.firstIDFull()
			 || this.firstValues()
			 || this.firstOptChild();
	}

	Tag parseTag() {
		try {
			return this.parseTagImpl();
		} catch(ParseException e) {
			throw new ParseException(
				"While parsing a Tag an Exception was thrown.",
				e, __FILE__, __LINE__
			);
		}
	}

	Tag parseTagImpl() {
		string[] subRules;
		subRules = ["IA", "IAO", "IAOT", "IAT", "IE", "IET", "IO", "IOT", "IV", "IVA", "IVAO", "IVAOT", "IVAT", "IVO", "IVOT", "IVT"];
		if(this.firstIDFull()) {
			IDFull id = this.parseIDFull();
			subRules = ["IV", "IVA", "IVAO", "IVAOT", "IVAT", "IVO", "IVOT", "IVT"];
			if(this.firstValues()) {
				Values vals = this.parseValues();
				subRules = ["IVA", "IVAO", "IVAOT", "IVAT"];
				if(this.firstAttributes()) {
					Attributes attrs = this.parseAttributes();
					subRules = ["IVAO", "IVAOT"];
					if(this.firstOptChild()) {
						OptChild oc = this.parseOptChild();
						subRules = ["IVAOT"];
						if(this.firstTagTerminator()) {
							this.parseTagTerminator();

							return new Tag(TagEnum.IVAOT
								, id
								, vals
								, attrs
								, oc
							);
						}
						return new Tag(TagEnum.IVAO
							, id
							, vals
							, attrs
							, oc
						);
					} else if(this.firstTagTerminator()) {
						this.parseTagTerminator();

						return new Tag(TagEnum.IVAT
							, id
							, vals
							, attrs
						);
					}
					return new Tag(TagEnum.IVA
						, id
						, vals
						, attrs
					);
				} else if(this.firstOptChild()) {
					OptChild oc = this.parseOptChild();
					subRules = ["IVOT"];
					if(this.firstTagTerminator()) {
						this.parseTagTerminator();

						return new Tag(TagEnum.IVOT
							, id
							, vals
							, oc
						);
					}
					return new Tag(TagEnum.IVO
						, id
						, vals
						, oc
					);
				} else if(this.firstTagTerminator()) {
					this.parseTagTerminator();

					return new Tag(TagEnum.IVT
						, id
						, vals
					);
				}
				return new Tag(TagEnum.IV
					, id
					, vals
				);
			} else if(this.firstAttributes()) {
				Attributes attrs = this.parseAttributes();
				subRules = ["IAO", "IAOT"];
				if(this.firstOptChild()) {
					OptChild oc = this.parseOptChild();
					subRules = ["IAOT"];
					if(this.firstTagTerminator()) {
						this.parseTagTerminator();

						return new Tag(TagEnum.IAOT
							, id
							, attrs
							, oc
						);
					}
					return new Tag(TagEnum.IAO
						, id
						, attrs
						, oc
					);
				} else if(this.firstTagTerminator()) {
					this.parseTagTerminator();

					return new Tag(TagEnum.IAT
						, id
						, attrs
					);
				}
				return new Tag(TagEnum.IA
					, id
					, attrs
				);
			} else if(this.firstOptChild()) {
				OptChild oc = this.parseOptChild();
				subRules = ["IOT"];
				if(this.firstTagTerminator()) {
					this.parseTagTerminator();

					return new Tag(TagEnum.IOT
						, id
						, oc
					);
				}
				return new Tag(TagEnum.IO
					, id
					, oc
				);
			} else if(this.firstTagTerminator()) {
				this.parseTagTerminator();

				return new Tag(TagEnum.IET
					, id
				);
			}
			return new Tag(TagEnum.IE
				, id
			);
		} else if(this.firstValues()) {
			Values vals = this.parseValues();
			subRules = ["VA", "VAO", "VAOT", "VAT"];
			if(this.firstAttributes()) {
				Attributes attrs = this.parseAttributes();
				subRules = ["VAO", "VAOT"];
				if(this.firstOptChild()) {
					OptChild oc = this.parseOptChild();
					subRules = ["VAOT"];
					if(this.firstTagTerminator()) {
						this.parseTagTerminator();

						return new Tag(TagEnum.VAOT
							, vals
							, attrs
							, oc
						);
					}
					return new Tag(TagEnum.VAO
						, vals
						, attrs
						, oc
					);
				} else if(this.firstTagTerminator()) {
					this.parseTagTerminator();

					return new Tag(TagEnum.VAT
						, vals
						, attrs
					);
				}
				return new Tag(TagEnum.VA
					, vals
					, attrs
				);
			} else if(this.firstOptChild()) {
				OptChild oc = this.parseOptChild();
				subRules = ["VOT"];
				if(this.firstTagTerminator()) {
					this.parseTagTerminator();

					return new Tag(TagEnum.VOT
						, vals
						, oc
					);
				}
				return new Tag(TagEnum.VO
					, vals
					, oc
				);
			} else if(this.firstTagTerminator()) {
				this.parseTagTerminator();

				return new Tag(TagEnum.VT
					, vals
				);
			}
			return new Tag(TagEnum.V
				, vals
			);
		} else if(this.firstOptChild()) {
			OptChild oc = this.parseOptChild();
			subRules = ["OT"];
			if(this.firstTagTerminator()) {
				this.parseTagTerminator();

				return new Tag(TagEnum.OT
					, oc
				);
			}
			return new Tag(TagEnum.O
				, oc
			);
		}
		auto app = appender!string();
		formattedWrite(app, 
			"In 'Tag' found a '%s' while looking for", 
			this.lex.front
		);
		throw new ParseException(app.data,
			__FILE__, __LINE__,
			subRules,
			["ident","value","lcurly"]
		);

	}

	bool firstIDFull() const pure @nogc @safe {
		return this.lex.front.type == TokenType.ident;
	}

	IDFull parseIDFull() {
		try {
			return this.parseIDFullImpl();
		} catch(ParseException e) {
			throw new ParseException(
				"While parsing a IDFull an Exception was thrown.",
				e, __FILE__, __LINE__
			);
		}
	}

	IDFull parseIDFullImpl() {
		string[] subRules;
		subRules = ["L", "S"];
		if(this.lex.front.type == TokenType.ident) {
			Token cur = this.lex.front;
			this.lex.popFront();
			subRules = ["L"];
			if(this.lex.front.type == TokenType.colon) {
				this.lex.popFront();
				subRules = ["L"];
				if(this.firstIDFull()) {
					IDFull follow = this.parseIDFull();

					return new IDFull(IDFullEnum.L
						, cur
						, follow
					);
				}
				auto app = appender!string();
				formattedWrite(app, 
					"In 'IDFull' found a '%s' while looking for", 
					this.lex.front
				);
				throw new ParseException(app.data,
					__FILE__, __LINE__,
					subRules,
					["ident"]
				);

			}
			return new IDFull(IDFullEnum.S
				, cur
			);
		}
		auto app = appender!string();
		formattedWrite(app, 
			"In 'IDFull' found a '%s' while looking for", 
			this.lex.front
		);
		throw new ParseException(app.data,
			__FILE__, __LINE__,
			subRules,
			["ident"]
		);

	}

	bool firstValues() const pure @nogc @safe {
		return this.lex.front.type == TokenType.value;
	}

	Values parseValues() {
		try {
			return this.parseValuesImpl();
		} catch(ParseException e) {
			throw new ParseException(
				"While parsing a Values an Exception was thrown.",
				e, __FILE__, __LINE__
			);
		}
	}

	Values parseValuesImpl() {
		string[] subRules;
		subRules = ["Value", "ValueFollow"];
		if(this.lex.front.type == TokenType.value) {
			Token cur = this.lex.front;
			this.lex.popFront();
			subRules = ["ValueFollow"];
			if(this.firstValues()) {
				Values follow = this.parseValues();

				return new Values(ValuesEnum.ValueFollow
					, cur
					, follow
				);
			}
			return new Values(ValuesEnum.Value
				, cur
			);
		}
		auto app = appender!string();
		formattedWrite(app, 
			"In 'Values' found a '%s' while looking for", 
			this.lex.front
		);
		throw new ParseException(app.data,
			__FILE__, __LINE__,
			subRules,
			["value"]
		);

	}

	bool firstAttributes() const pure @nogc @safe {
		return this.firstAttribute();
	}

	Attributes parseAttributes() {
		try {
			return this.parseAttributesImpl();
		} catch(ParseException e) {
			throw new ParseException(
				"While parsing a Attributes an Exception was thrown.",
				e, __FILE__, __LINE__
			);
		}
	}

	Attributes parseAttributesImpl() {
		string[] subRules;
		subRules = ["Attribute", "AttributeFollow"];
		if(this.firstAttribute()) {
			Attribute cur = this.parseAttribute();
			subRules = ["AttributeFollow"];
			if(this.firstAttributes()) {
				Attributes follow = this.parseAttributes();

				return new Attributes(AttributesEnum.AttributeFollow
					, cur
					, follow
				);
			}
			return new Attributes(AttributesEnum.Attribute
				, cur
			);
		}
		auto app = appender!string();
		formattedWrite(app, 
			"In 'Attributes' found a '%s' while looking for", 
			this.lex.front
		);
		throw new ParseException(app.data,
			__FILE__, __LINE__,
			subRules,
			["ident -> IDFull"]
		);

	}

	bool firstAttribute() const pure @nogc @safe {
		return this.firstIDFull();
	}

	Attribute parseAttribute() {
		try {
			return this.parseAttributeImpl();
		} catch(ParseException e) {
			throw new ParseException(
				"While parsing a Attribute an Exception was thrown.",
				e, __FILE__, __LINE__
			);
		}
	}

	Attribute parseAttributeImpl() {
		string[] subRules;
		subRules = ["A"];
		if(this.firstIDFull()) {
			IDFull id = this.parseIDFull();
			subRules = ["A"];
			if(this.lex.front.type == TokenType.assign) {
				this.lex.popFront();
				subRules = ["A"];
				if(this.lex.front.type == TokenType.value) {
					Token value = this.lex.front;
					this.lex.popFront();

					return new Attribute(AttributeEnum.A
						, id
						, value
					);
				}
				auto app = appender!string();
				formattedWrite(app, 
					"In 'Attribute' found a '%s' while looking for", 
					this.lex.front
				);
				throw new ParseException(app.data,
					__FILE__, __LINE__,
					subRules,
					["value"]
				);

			}
			auto app = appender!string();
			formattedWrite(app, 
				"In 'Attribute' found a '%s' while looking for", 
				this.lex.front
			);
			throw new ParseException(app.data,
				__FILE__, __LINE__,
				subRules,
				["assign"]
			);

		}
		auto app = appender!string();
		formattedWrite(app, 
			"In 'Attribute' found a '%s' while looking for", 
			this.lex.front
		);
		throw new ParseException(app.data,
			__FILE__, __LINE__,
			subRules,
			["ident"]
		);

	}

	bool firstOptChild() const pure @nogc @safe {
		return this.lex.front.type == TokenType.lcurly;
	}

	OptChild parseOptChild() {
		try {
			return this.parseOptChildImpl();
		} catch(ParseException e) {
			throw new ParseException(
				"While parsing a OptChild an Exception was thrown.",
				e, __FILE__, __LINE__
			);
		}
	}

	OptChild parseOptChildImpl() {
		string[] subRules;
		subRules = ["E", "E2", "T"];
		if(this.lex.front.type == TokenType.lcurly) {
			this.lex.popFront();
			subRules = ["E", "T"];
			if(this.firstTagTerminator()) {
				this.parseTagTerminator();
				subRules = ["T"];
				if(this.firstTags()) {
					Tags tags = this.parseTags();
					subRules = ["T"];
					if(this.lex.front.type == TokenType.rcurly) {
						this.lex.popFront();

						return new OptChild(OptChildEnum.T
							, tags
						);
					}
					auto app = appender!string();
					formattedWrite(app, 
						"In 'OptChild' found a '%s' while looking for", 
						this.lex.front
					);
					throw new ParseException(app.data,
						__FILE__, __LINE__,
						subRules,
						["rcurly"]
					);

				} else if(this.lex.front.type == TokenType.rcurly) {
					this.lex.popFront();

					return new OptChild(OptChildEnum.E
					);
				}
				auto app = appender!string();
				formattedWrite(app, 
					"In 'OptChild' found a '%s' while looking for", 
					this.lex.front
				);
				throw new ParseException(app.data,
					__FILE__, __LINE__,
					subRules,
					["ident -> Tag","lcurly -> Tag","value -> Tag","rcurly"]
				);

			} else if(this.lex.front.type == TokenType.rcurly) {
				this.lex.popFront();

				return new OptChild(OptChildEnum.E2
				);
			}
			auto app = appender!string();
			formattedWrite(app, 
				"In 'OptChild' found a '%s' while looking for", 
				this.lex.front
			);
			throw new ParseException(app.data,
				__FILE__, __LINE__,
				subRules,
				["eol","semicolon","rcurly"]
			);

		}
		auto app = appender!string();
		formattedWrite(app, 
			"In 'OptChild' found a '%s' while looking for", 
			this.lex.front
		);
		throw new ParseException(app.data,
			__FILE__, __LINE__,
			subRules,
			["lcurly"]
		);

	}

	bool firstTagTerminator() const pure @nogc @safe {
		return this.lex.front.type == TokenType.eol
			 || this.lex.front.type == TokenType.semicolon;
	}

	TagTerminator parseTagTerminator() {
		try {
			return this.parseTagTerminatorImpl();
		} catch(ParseException e) {
			throw new ParseException(
				"While parsing a TagTerminator an Exception was thrown.",
				e, __FILE__, __LINE__
			);
		}
	}

	TagTerminator parseTagTerminatorImpl() {
		string[] subRules;
		subRules = ["E", "EF"];
		if(this.lex.front.type == TokenType.eol) {
			this.lex.popFront();
			subRules = ["EF"];
			if(this.firstTagTerminator()) {
				this.parseTagTerminator();

				return new TagTerminator(TagTerminatorEnum.EF
				);
			}
			return new TagTerminator(TagTerminatorEnum.E
			);
		} else if(this.lex.front.type == TokenType.semicolon) {
			this.lex.popFront();
			subRules = ["SF"];
			if(this.firstTagTerminator()) {
				this.parseTagTerminator();

				return new TagTerminator(TagTerminatorEnum.SF
				);
			}
			return new TagTerminator(TagTerminatorEnum.S
			);
		}
		auto app = appender!string();
		formattedWrite(app, 
			"In 'TagTerminator' found a '%s' while looking for", 
			this.lex.front
		);
		throw new ParseException(app.data,
			__FILE__, __LINE__,
			subRules,
			["eol","semicolon"]
		);

	}

}
