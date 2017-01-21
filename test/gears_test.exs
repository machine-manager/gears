alias Gears.{LangUtil, FileUtil, StringUtil, TableFormatter}

defmodule Gears.LangUtilTest do
	use ExUnit.Case

	test "oper_if works on binaries" do
		import LangUtil, only: [oper_if: 3]

		s = "hello"
		out = {s, &Kernel.<>/2}
			|> oper_if(true,  " ")
			|> oper_if(false, "mars")
			|> oper_if(true,  "world")
			|> elem(0)
		assert out == "hello world"
	end

	test "oper_if works on lists" do
		import LangUtil, only: [oper_if: 3]

		s = ["hello"]
		out = {s, &Kernel.++/2}
			|> oper_if(true,  [" "])
			|> oper_if(false, ["mars"])
			|> oper_if(true,  ["world"])
			|> elem(0)
		assert out == ["hello", " ", "world"]
	end

	test "oper_if doesn't evaluate expression unless condition is truthy" do
		import LangUtil, only: [oper_if: 3]

		s = "hello"
		out = {s, &Kernel.<>/2}
			|> oper_if(false, "#{:foo + 1}")
			|> oper_if(nil,   "#{:foo + 2}")
			|> elem(0)
		assert out == "hello"
	end

	test "ok_or_raise works" do
		import LangUtil

		assert :ok == ok_or_raise(:ok)
		assert_raise ArithmeticError, fn ->
			ok_or_raise({:error, ArithmeticError})
		end
	end
end

defmodule Gears.FileUtilTest do
	use ExUnit.Case

	test "temp_path returns a string" do
		assert is_binary(FileUtil.temp_path("prefix", "jpg"))
	end

	test "temporary path starts with System.tmp_dir/prefix" do
		prefix = "prefix"
		path = FileUtil.temp_path(prefix, "jpg")
		assert String.starts_with?(path, Path.join(System.tmp_dir, prefix))
	end

	test "if extension provided, temporary path ends with '.extension'" do
		extension = "jpg"
		path = FileUtil.temp_path("prefix", extension)
		assert String.ends_with?(path, ".#{extension}")
		assert not String.ends_with?(path, "..#{extension}")
	end

	test "if extension empty, temporary path does not end with '.'" do
		extension = ""
		path = FileUtil.temp_path("prefix", extension)
		assert not String.ends_with?(path, ".")
	end

	test "if extension not provided, temporary path does not end with '.'" do
		path = FileUtil.temp_path("prefix")
		assert not String.ends_with?(path, ".")
	end
end

defmodule Gears.StringUtilTest do
	use ExUnit.Case

	test "grep" do
		assert StringUtil.grep("hello\nworld\norange",   ~r"l")      == ["hello", "world"]
		assert StringUtil.grep("hello\nworld\norange",   ~r"^.{6}$") == ["orange"]
		assert StringUtil.grep("hello\nworld\norange",   ~r"^$")     == []
		assert StringUtil.grep("hello\nworld\norange\n", ~r"^$")     == [""]
	end

	test "remove_empty_lines" do
		assert StringUtil.remove_empty_lines("") == ""
		assert StringUtil.remove_empty_lines("\n") == ""
		assert StringUtil.remove_empty_lines("\nline") == "line"
		assert StringUtil.remove_empty_lines("\n\nline") == "line"
		assert StringUtil.remove_empty_lines("\n\nline\n") == "line\n"
		assert StringUtil.remove_empty_lines("\n\nline\n\n") == "line\n"
		assert StringUtil.remove_empty_lines("hello\nworld") == "hello\nworld"
		assert StringUtil.remove_empty_lines("hello\nworld\n") == "hello\nworld\n"
		assert StringUtil.remove_empty_lines("hello\n\n\nworld\n\n\n") == "hello\nworld\n"
	end

	test "counted_noun" do
		assert StringUtil.counted_noun(0, "unit", "units") == "0 units"
		assert StringUtil.counted_noun(1, "unit", "units") == "1 unit"
		assert StringUtil.counted_noun(2, "unit", "units") == "2 units"
	end

	test "half_width_length" do
		assert StringUtil.half_width_length("")      == 0
		assert StringUtil.half_width_length("h")     == 1
		assert StringUtil.half_width_length("hi")    == 2
		assert StringUtil.half_width_length("末")    == 2
		assert StringUtil.half_width_length("末未")  == 4
		assert StringUtil.half_width_length("末未.") == 5
	end

	test "strip_ansi" do
		assert StringUtil.strip_ansi("")           == ""
		assert StringUtil.strip_ansi("hi")         == "hi"
		assert StringUtil.strip_ansi(bolded("hi")) == "hi"
	end

	defp bolded(s) do
		"#{IO.ANSI.bright()}#{s}#{IO.ANSI.normal()}"
	end
end

defmodule Gears.TableFormatterTest do
	use ExUnit.Case

	@bad_data [[1, "hello", -0.555], [1000000000, "world", ""], [3, "longer data", 3.5]]
	@data     [["1", "hello", "-0.555"], ["1000000000", "world", ""], ["3", "longer data", "3.5"]]

	test "table formatter with default padding" do
		# Note that strings in the last column are not padded
		assert TableFormatter.format(@data) |> IO.iodata_to_binary ==
			"""
			1          hello       -0.555
			1000000000 world       
			3          longer data 3.5
			"""
	end

	test "table formatter with padding of 2" do
		assert TableFormatter.format(@data, padding: 2) |> IO.iodata_to_binary ==
			"""
			1           hello        -0.555
			1000000000  world        
			3           longer data  3.5
			"""
	end

	test "table formatter with padding of 0" do
		assert TableFormatter.format(@data, padding: 0) |> IO.iodata_to_binary ==
			"""
			1         hello      -0.555
			1000000000world      
			3         longer data3.5
			"""
	end

	test "table formatter with a width_fn that strips ANSI" do
		underlined_data = @data |> Enum.map(fn row -> row |> Enum.map(&underlined/1) end)
		assert TableFormatter.format(underlined_data, width_fn: &(&1 |> strip_ansi |> String.length))
		       |> IO.iodata_to_binary |> strip_ansi ==
			"""
			1          hello       -0.555
			1000000000 world       
			3          longer data 3.5
			"""
	end

	defp underlined(s) do
		"#{IO.ANSI.underline()}#{s}#{IO.ANSI.no_underline()}"
	end

	defp strip_ansi(s) do
		# Based on https://github.com/chalk/ansi-regex/blob/dce3806b159260354de1a77c1db543a967f7218f/index.js
		s |> String.replace(~r/[\x{001b}\x{009b}][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]/, "")
	end

	test "table formatter with 0 rows" do
		assert TableFormatter.format([], padding: 1) |> IO.iodata_to_binary == ""
	end

	test "raises error on non-string values" do
		assert_raise ArgumentError, ~r/^All values /, fn -> TableFormatter.format(@bad_data) end
	end
end
