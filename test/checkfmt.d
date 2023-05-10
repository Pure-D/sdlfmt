/++ dub.sdl:
name "checkfmt"
dependency "sdlfmt" path=".."
+/

import sdlfmt;
import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.path;
import std.range;
import std.stdio;

SdlFmtConfig deserializeConfig(string name)
{
	if (name == "default")
		return SdlFmtConfig.init;

	scope (failure)
		stderr.writeln("Failed parsing config '", name, "'");

	SdlFmtConfig ret;
	bool start = true;
	while (name.length)
	{
		if (start)
			start = false;
		else if (name.startsWith("-"))
			name = name[1 .. $];
		else
			throw new Exception("invalid format, expected `option-option-...` as format config");
		if (name.startsWith("tabs-"))
		{
			name = name["tabs-".length .. $];
			auto count = name.parse!int;
			enforce(name.startsWith("-") || !name.length, "invalid format, expected `tabs-N`, where N is an integer");
			ret.indent = '\t'.repeat(count).array;
		}
		else if (name.startsWith("spaces-"))
		{
			name = name["spaces-".length .. $];
			auto count = name.parse!int;
			enforce(name.startsWith("-") || !name.length, "invalid format, expected `spaces-N`, where N is an integer");
			ret.indent = ' '.repeat(count).array;
		}
		else if (name.startsWith("tempws-"))
		{
			name = name["tempws-".length .. $];
			ret.backslashTempIndent = name.parse!int;
			enforce(name.startsWith("-") || !name.length, "invalid format, expected `tempws-N`, where N is an integer");
		}
		else if (name.startsWith("equals_ws"))
		{
			name = name["equals_ws".length .. $];
			ret.whitespaceAroundEquals = true;
		}
		else if (name.startsWith("crlf"))
		{
			name = name["crlf".length .. $];
			ret.lineEnding = "\r\n";
		}
		else if (name.startsWith("lf"))
		{
			name = name["lf".length .. $];
			ret.lineEnding = "\n";
		}
		else if (name.startsWith("cr"))
		{
			name = name["cr".length .. $];
			ret.lineEnding = "\r";
		}
		else
			throw new Exception("Unknown format part, known parts: tabs-N, spaces-N, tempws-N, equals_ws, lf, cr, crlf");
	}

	return ret;
}

int main(string[] args)
{
	import std.file : write;

	if (args.length > 1 && args[1] == "generate")
	{
		enforce(args.length > 2, "Usage: " ~ args[0] ~ " generate [file] ([options])\nwhere options is the serialized options name (folder name in results)");
		auto serializedOptions = args.length > 3 ? args[3] : "default";
		auto options = deserializeConfig(serializedOptions);
		auto dir = buildPath("results", serializedOptions);
		if (!exists(dir))
			mkdir(dir);
		write(
			buildPath(dir, args[2].baseName),
			options.format(args[2].readText, args[2])
		);
		return 0;
	}

	enforce(exists("results"), "Missing 'results' directory");
	enforce(exists("source"), "Missing 'source' directory");
	if (!exists("actual"))
		mkdir("actual");

	int fails;

	auto missingSourceFiles = dirEntries("source", SpanMode.shallow).map!"a.name".array;
	auto testFiles = dirEntries("results", SpanMode.breadth).filter!"a.isFile".map!"a.name".array.sort!"a<b";
	auto maxLen = testFiles.map!"a.length".maxElement;
	foreach (test; testFiles)
	{
		writef("%*-s ", maxLen, test);
		assert(test.startsWith("results/", "results\\"));
		auto parts = test["results/".length .. $];
		auto config = dirName(parts).deserializeConfig;
		auto sourceName = buildPath("source", baseName(parts));
		missingSourceFiles = missingSourceFiles.remove!(a => a == sourceName);

		auto actual = config.format(sourceName.readText, sourceName);
		auto expected = readText(test);

		write(buildPath("actual", dirName(parts) ~ "-" ~ baseName(parts)), actual);

		if (actual != expected)
		{
			writeln("\x1B[1;31mFAIL\x1B[m");
			fails++;
		}
		else
			writeln("\x1B[32mPASS\x1B[m");
	}

	foreach (missing; missingSourceFiles)
		writeln("\x1B[1;33mWARNING:\x1B[0m source file ", missing,
			" has no tests!\n\tMaybe generate it with: ", args[0], " generate ", missing);

	if (fails > 0)
	{
		writeln(fails, fails == 1 ? " test has" : " tests have", " failed!");
		return 1;
	}
	return 0;
}