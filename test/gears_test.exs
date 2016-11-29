alias Gears.{LangUtil, FileUtil, StringUtil}

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

	test "grep works" do
		assert StringUtil.grep("hello\nworld\norange",   ~r"l")      == ["hello", "world"]
		assert StringUtil.grep("hello\nworld\norange",   ~r"^.{6}$") == ["orange"]
		assert StringUtil.grep("hello\nworld\norange",   ~r"^$")     == []
		assert StringUtil.grep("hello\nworld\norange\n", ~r"^$")     == [""]
	end
end
