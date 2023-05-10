import sdlfmt;
import std.array;
import std.file;
import std.getopt;
import std.stdio;
import std.utf : validate;

int main(string[] args)
{
	GetoptResult getoptHelp;
	SdlFmtConfig config = SdlFmtConfig.getopt(args, getoptHelp);

	bool inplace;
	auto extraGetopt = args.getopt(std.getopt.config.passThrough,
		"inplace|i", "Edit files in place", &inplace);

	void printUsage()
	{
		defaultGetoptPrinter(
			"Auto-formatter for SDLang files\nUsage:\n"
			~ "\tsdlfmt [OPTIONS...] [--] FILENAMES..."
			~ "\n\n General options:", extraGetopt.options);
		defaultGetoptPrinter("\nFormatter options:", getoptHelp.options[0 .. $ - 1]); // exclude -h / --help
		writeln();
		writeln("Use - as only file name if you want to read from stdin");
		writeln();
		writeln("By default, only a single file can be passed in as input and the formatted");
		writeln("output will be dumped to stdout. Use --inplace to be able to specify multiple");
		writeln("input files.");
	}

	if (getoptHelp.helpWanted)
	{
		printUsage();
		return 0;
	}

	if (args.length == 1)
	{
		printUsage();
		return 1;
	}

	auto files = args[1 .. $];

	version (Windows)
	{
		// On Windows, set stdout to binary mode (needed for correct EOL writing)
		// See Phobos' stdio.File.rawWrite
		{
			import std.stdio : _O_BINARY;
			immutable fd = stdout.fileno;
			_setmode(fd, _O_BINARY);
			version (CRuntime_DigitalMars)
			{
				import core.atomic : atomicOp;
				import core.stdc.stdio : __fhnd_info, FHND_TEXT;

				atomicOp!"&="(__fhnd_info[fd], ~FHND_TEXT);
			}
		}
	}

	if (files == ["-"])
	{
		auto buffer = appender!(const(ubyte)[]);
		ubyte[4096] inputBuffer;
		while (true)
		{
			auto b = stdin.rawRead(inputBuffer[]);
			if (b.length)
				buffer ~= b;
			else
				break;
		}
		auto text = cast(const(char)[]) buffer.data;

		validate(text);

		auto result = config.format(text, "(stdin)");
		// never stream to stdout!
		stdout.rawWrite(result);
	}
	else if (inplace)
	{
		import std.file : write;

		foreach (file; files)
		{
			auto input = readText(file);
			auto result = config.format(input, file);
			// never stream to this file!
			write(file, result);
		}
	}
	else
	{
		if (files.length > 1)
		{
			stderr.writeln("Must run with `--inplace` if you want to specify multiple input files");
			return 1;
		}

		auto result = config.format(readText(files[0]), files[0]);
		// never stream to stdout!
		stdout.rawWrite(result);
	}

	return 0;
}
