defmodule Gears do
	defmodule LangUtil do
		@doc ~S"""
		For use in a pipeline like so:

			{s, &Kernel.<>/2}
				|> oper_if(c.section,          "Section: #{c.section}\n")
				|> oper_if(true,               "Description: #{c.short_description}\n")
				|> oper_if(c.long_description, prefix_every_line(c.long_description, " ") <> "\n")
				|> elem(0)

		`expression` is not evaluated unless evaluation of `clause` is truthy.  This avoids
		blowing up on nils and other unexpected values.
		"""
		defmacro oper_if(state, clause, expression) do
			quote do
				{acc, operator} = unquote(state)
				result = if unquote(clause) do
					operator.(acc, unquote(expression))
				else
					acc
				end
				{result, operator}
			end
		end

		def ok_or_raise({:error, term}), do: raise term
		def ok_or_raise(:ok), do: :ok
	end

	defmodule FileUtil do
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
			path = Path.join(System.tmp_dir, "#{prefix}-#{random}")
			path <> case String.first(extension) do
				nil -> ""
				_   -> ".#{extension}"
			end
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

	defmodule StringUtil do
		@doc """
		Take a multi-line string `s` and return a list of lines that match `regexp`.
		"""
		def grep(s, regexp) do
			s
			|> String.split("\n")
			|> Enum.filter(&(String.match?(&1, regexp)))
		end

		def counted_noun(count, singular, plural) do
			case count do
				1 -> "#{count} #{singular}"
				_ -> "#{count} #{plural}"
			end
		end
	end

	defmodule SystemUtil do
		def print_stack() do
			IO.write("\n")
			IO.write("=========================== stack trace ===========================\n")
			IO.write(Exception.format_stacktrace())
			IO.write("===================================================================\n")
		end
	end

	# Based on Patrick Oscity's answer at
	# http://stackoverflow.com/questions/30749400/output-tabular-data-with-io-ansi
	defmodule TableFormatter do
		def format(rows, opts \\ []) do
			padding         = Keyword.get(opts, :padding, 1)
			rows            = stringify(rows)
			widths          = rows |> transpose |> column_widths
			# Don't pad strings in the last column
			widths          = Enum.drop(widths, -1) ++ [-padding]
			rows
			|> pad_cells(widths, padding)
			|> join_rows
		end

		defp pad_cells(rows, widths, padding) do
			Enum.map(rows, fn row ->
				for {val, width} <- Enum.zip(row, widths) do
					String.pad_trailing(val, width + padding)
				end
			end)
		end

		defp join_rows(rows) do
			# Make sure we get a trailing newline
			Stream.concat(rows, [[""]])
			|> Enum.map(&Enum.join/1)
			|> Enum.join("\n")
		end

		defp stringify(rows) do
			Enum.map(rows, fn row ->
				Enum.map(row, &to_string/1)
			end)
		end

		defp column_widths(columns) do
			Enum.map(columns, fn column ->
				column |> Enum.map(&String.length/1) |> Enum.max
			end)
		end

		# http://stackoverflow.com/questions/23705074
		defp transpose([[]|_]), do: []
		defp transpose(rows) do
			[Enum.map(rows, &hd/1) | transpose(Enum.map(rows, &tl/1))]
		end
	end
end
