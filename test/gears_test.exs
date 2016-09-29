defmodule Gears.LangUtilTest do
	use ExUnit.Case

	test "ok_or_raise works" do
		import Gears.LangUtil

		assert :ok == ok_or_raise(:ok)
		assert_raise ArithmeticError, fn ->
			ok_or_raise({:error, ArithmeticError})
		end
	end
end

defmodule Gears.FileUtilTest do
	use ExUnit.Case

	test "temp_path returns a string" do
		assert is_binary(Gears.FileUtil.temp_path("prefix", "jpg"))
	end

	test "temporary path starts with System.tmp_dir/prefix" do
		prefix = "prefix"
		path = Gears.FileUtil.temp_path(prefix, "jpg")
		assert String.starts_with?(path, Path.join(System.tmp_dir, prefix))
	end

	test "if extension provided, temporary path ends with '.extension'" do
		extension = "jpg"
		path = Gears.FileUtil.temp_path("prefix", extension)
		assert String.ends_with?(path, ".#{extension}")
		assert not String.ends_with?(path, "..#{extension}")
	end

	test "if extension empty, temporary path does not end with '.'" do
		extension = ""
		path = Gears.FileUtil.temp_path("prefix", extension)
		assert not String.ends_with?(path, ".")
	end

	test "if extension not provided, temporary path does not end with '.'" do
		path = Gears.FileUtil.temp_path("prefix")
		assert not String.ends_with?(path, ".")
	end
end
