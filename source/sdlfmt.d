module sdlfmt;

version (NoGetOpt)
{
}
else
	version = WithGetOpt;

import sdlite.lexer;
import std.algorithm;
import std.array;
import std.ascii;
import std.string;

struct SdlFmtConfig
{
	string lineEnding = "\n";
	string indent = "\t";
	bool whitespaceAroundEquals = false;
	int backslashTempIndent = 2;

	version (WithGetOpt)
	{
		import std.getopt;

		static SdlFmtConfig getopt(ref string[] args)
		{
			GetoptResult dummy;
			return getopt(args, dummy);
		}

		static SdlFmtConfig getopt(ref string[] args, ref GetoptResult getoptResult)
		{
			import std.range;

			SdlFmtConfig ret;
			char indentStyle = '\t';
			int indentSize = -1;

			void mapEol(string option, string value)
			{
				switch (value)
				{
				case "cr": ret.lineEnding = "\r"; break;
				case "lf": ret.lineEnding = "\n"; break;
				case "crlf": ret.lineEnding = "\r\n"; break;
				default:
					throw new GetOptException("Unrecognized end-of-line type '" ~ value ~ "', recognized: lf, cr, crlf");
				}
			}

			void mapIndentStyle(string option, string value)
			{
				switch (value)
				{
				case "tab": indentStyle = '\t'; break;
				case "space": indentStyle = ' '; break;
				default:
					throw new GetOptException("Unrecognized end-of-line type '" ~ value ~ "', recognized: lf, cr, crlf");
				}
			}

			getoptResult = std.getopt.getopt(args,
				config.passThrough,
				"end_of_line", "(lf|cr|crlf)", &mapEol,
				"indent_style|t", "(tab|space)", &mapIndentStyle,
				"indent_size", "(default = 1 for tab, 4 for space)", &indentSize,
				"whitespace_around_equals", "(default = false)", &ret.whitespaceAroundEquals,
				"backslash_temp_indent_size", "(default = 2)", &ret.backslashTempIndent,
			);

			if (indentStyle == '\t' && indentSize == -1)
				ret.indent = "\t";
			else if (indentStyle == ' ' && indentSize == -1)
				ret.indent = "    ";
			else
				ret.indent = indentStyle.repeat(indentSize).array;

			return ret;
		}
	}
}

string format(SdlFmtConfig config, scope const(char)[] sdl, string filename = "")
{
	auto ret = appender!string;
	size_t[] neededNewLines;
	size_t lastNewLineIndex;
	bool queueNewLine;

	int indent = 0;
	int multiLineIndent = 0;
	int lineNo = 0;

	void putIndentIfNeeded()
	{
		if (queueNewLine)
		{
			ret ~= config.lineEnding;
			queueNewLine = false;
		}

		if (!ret.data.length || ret.data[$ - 1] == '\n' || ret.data[$ - 1] == '\r')
			foreach (i; 0 .. indent + multiLineIndent)
				ret ~= config.indent;
		multiLineIndent = 0;
	}

	bool needsSpaceAfter(dchar c)
	{
		if (c == '=')
			return config.whitespaceAroundEquals;
		if (c == ':')
			return false;
		return !c.isWhite;
	}

	bool wantSpaceHere()
	{
		return ret.data.length && needsSpaceAfter(ret.data[$ - 1]) && !queueNewLine;
	}

	bool isComment(scope const(char)[] sdl)
	{
		if (sdl.startsWith("//", "--", "#"))
			return true;
		else if (sdl.startsWith("/*"))
			return sdl.endsWith("*/") && !sdl[0 .. $ - 2].canFind("*/");
		else
			return false;
	}

	bool isAfterEmptyOrCommentLine(scope const(char)[] sdl)
	{
		if (!sdl.endsWith(config.lineEnding))
			return false;
		auto slice = sdl[0 .. $ - config.lineEnding.length];
		if (slice.endsWith(config.lineEnding))
			return true;

		auto start = slice.lastIndexOf(config.lineEnding);
		if (start == -1)
			start = 0;
		else
			start += config.lineEnding.length;

		return isComment(slice[start .. $].strip);
	}

	bool isStartOfBlock(scope const(char)[] sdl)
	{
		if (sdl.stripRight.endsWith('{'))
			return true;

		auto start = sdl.lastIndexOf('{');
		if (start == -1)
			return false;

		return isComment(sdl[start + 1 .. $].strip);
	}

	void putNewLineBeforeIfNeeded()
	{
		if (isAfterEmptyOrCommentLine(ret.data[0 .. lastNewLineIndex])
			|| isStartOfBlock(ret.data[0 .. lastNewLineIndex]))
			return;
		neededNewLines ~= lastNewLineIndex;
	}

	void appendFixedNewlines(T)(T text)
	{
		import std.uni : lineSep, paraSep;

		foreach (line; text.lineSplitter!(KeepTerminator.yes))
		{
			if (line.endsWith("\r\n"))
			{
				ret ~= line[0 .. $ - 2];
				ret ~= config.lineEnding;
			}
			else if (line.endsWith('\r', '\n', '\v', '\f', '\x85'))
			{
				ret ~= line[0 .. $ - 1];
				ret ~= config.lineEnding;
			}
			else
				ret ~= line;
		}
	}

	foreach (token; lexSDLang(sdl, filename))
	{
		final switch (token.type)
		{
		case TokenType.invalid:
			if (token.text.length == 1 && token.text[0] == '\\')
			{
				// multiline wrapper
				multiLineIndent += config.backslashTempIndent;
				if (wantSpaceHere)
					ret ~= " ";
				ret ~= '\\';
			}
			else
			{
				appendFixedNewlines(token.whitespacePrefix);
				appendFixedNewlines(token.text);
			}
			break;
		case TokenType.eof: break;
		case TokenType.eol:
			if (!ret.data.length || ret.data[$ - 1] != '\\')
				multiLineIndent = 0;
			lineNo++;
			if (ret.data.endsWith(config.lineEnding ~ config.lineEnding))
				break;
			ret ~= config.lineEnding;
			lastNewLineIndex = ret.data.length;
			queueNewLine = false;
			break;
		case TokenType.semicolon:
			putIndentIfNeeded();
			ret ~= ";";
			multiLineIndent = 0;
			break;
		case TokenType.blockClose:
			if (ret.data.length && !(ret.data[$ - 1] == '\n' || ret.data[$ - 1] == '\r'))
				ret ~= config.lineEnding;
			indent--;
			multiLineIndent = 0;
			queueNewLine = false;
			putIndentIfNeeded();
			ret ~= "}";
			queueNewLine = true;
			break;
		case TokenType.blockOpen:
			putNewLineBeforeIfNeeded();
			indent++;
			if (wantSpaceHere)
				ret ~= " ";
			else
				putIndentIfNeeded();

			ret ~= "{";
			queueNewLine = true;
			break;
		case TokenType.namespace:
			putIndentIfNeeded();
			ret ~= ":";
			break;
		case TokenType.assign:
			if (wantSpaceHere)
			{
				if (config.whitespaceAroundEquals)
					ret ~= " ";
			}
			else
				putIndentIfNeeded();
			ret ~= "=";
			break;
		case TokenType.comment:
			if (wantSpaceHere)
				ret ~= " ";
			else
				putIndentIfNeeded();

			appendFixedNewlines(token.text);
			if (ret.data.endsWith(config.lineEnding))
				lastNewLineIndex = ret.data.length;
			break;
		case TokenType.null_:
		case TokenType.text:
		case TokenType.binary:
		case TokenType.number:
		case TokenType.boolean:
		case TokenType.dateTime:
		case TokenType.date:
		case TokenType.duration:
		case TokenType.identifier:
			if (wantSpaceHere)
				ret ~= " ";
			else
				putIndentIfNeeded();

			appendFixedNewlines(token.text);
			break;
		}
	}

	if (ret.data.length && !ret.data.endsWith(config.lineEnding))
		ret ~= config.lineEnding;

	auto data = ret.data;
	if (!neededNewLines.length)
		return data;

	ret = appender!string;
	foreach (i, newLine; neededNewLines)
	{
		ret ~= data[i == 0 ? 0 : neededNewLines[i - 1] .. newLine];
		ret ~= config.lineEnding;
	}
	ret ~= data[neededNewLines[$ - 1] .. $];

	return ret.data;
}
