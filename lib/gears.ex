defmodule Gears do
	defmodule LangUtil do
		@doc ~S"""
		For use in a pipeline like so:

			s
			|> oper_if(c.section,          &Kernel.<>/2, "Section: #{c.section}\n")
			|> oper_if(true,               &Kernel.<>/2, "Description: #{c.short_description}\n")
			|> oper_if(c.long_description, &Kernel.<>/2, prefix_every_line(c.long_description, " ") <> "\n")

		`expression` is not evaluated unless evaluation of `clause` is truthy.  This avoids
		blowing up on nils and other unexpected values.
		"""
		defmacro oper_if(acc, clause, operator, expression) do
			quote do
				if unquote(clause) do
					unquote(operator).(unquote(acc), unquote(expression))
				else
					unquote(acc)
				end
			end
		end

		def ok_or_raise({:error, term}), do: raise term
		def ok_or_raise(:ok), do: :ok
	end

	defmodule FileUtil do
		import Gears.LangUtil, only: [oper_if: 4]

		@doc """
		Unlinks `path` if it exists.  Must be a file or an empty directory.
		The parent directories must exist in any case.
		"""
		@spec rm_f!(String.t) :: nil
		def rm_f!(path) do
			case File.rm(path) do
				:ok -> nil
				{:error, :enoent} -> nil
				{:error, reason} ->
					raise File.Error, reason: reason, action: "rm", path: path
			end
		end

		@spec temp_path(String.t, String.t) :: String.t
		def temp_path(prefix, extension \\ "") do
			random = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
			Path.join(System.tmp_dir, "#{prefix}-#{random}")
			|> oper_if(String.first(extension), &Kernel.<>/2, ".#{extension}")
		end

		@spec temp_dir(String.t) :: String.t
		def temp_dir(prefix) do
			p = temp_path(prefix)
			File.mkdir_p!(p)
			p
		end
	end

	defmodule IOUtil do
		def binwrite!(f, content) do
			LangUtil.ok_or_raise(IO.binwrite(f, content))
		end
	end
end
