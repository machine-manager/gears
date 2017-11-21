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

		def ok_or_raise({:error, term}), do: raise(term)
		def ok_or_raise(:ok), do: :ok
	end

	defmodule FileUtil do
		@doc """
		Unlinks `path` if it exists.  Ignores `enoent` errors; raises
		`File.Error` for any other error.
		"""
		@spec rm_f!(String.t) :: nil
		def rm_f!(path) do
			case File.rm(path) do
				:ok -> nil
				{:error, :enoent} -> nil
				{:error, reason} ->
					raise(File.Error, reason: reason, action: "rm", path: path)
			end
		end

		@_2_128 340282366920938463463374607431768211456

		@spec temp_path(String.t, String.t) :: String.t
		def temp_path(prefix, extension \\ "") do
			# Don't use :crypto.strong_rand_bytes because that requires erlang-crypto, which
			# may be linked to the wrong version of openssl when configuring a machine from
			# a machine_manager running on a different Debian/Ubuntu release.
			random =
				:rand.uniform(@_2_128)
				|> :binary.encode_unsigned
				|> Base.url_encode64(padding: false)
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

		@doc """
		Returns `true` if the given path exists. It can be regular file, directory,
		socket, symbolic link, named pipe or device file.

		Like `File.exists?`, but fixed to return `true` for dangling symlinks.
		"""
		def exists?(path) do
			match?({:ok, _}, :file.read_link_info(IO.chardata_to_string(path)))
		end

		@spec symlink?(String.t) :: String.t
		def symlink?(path) do
			case :file.read_link_all(path) do
				{:ok, _target} -> true
				_              -> false
			end
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

		@doc """
		Removes empty lines from a multi-line string.
		"""
		def remove_empty_lines(s) do
			s
			|> String.replace(~r/^\n+/,   "")
			|> String.replace(~r/\n{2,}/, "\n")
		end

		@doc """
		Takes (count, singular, plural) and returns either
		"count singular" (if count == 1) or "count plural" 
		"""
		def counted_noun(count, singular, plural) do
			case count do
				1 -> "#{count} #{singular}"
				_ -> "#{count} #{plural}"
			end
		end

		@doc """
		Returns the half-width length of a string.  Han characters count as 2
		and other characters count as 1.  This is not a complete implementation.
		See https://github.com/Qqwy/elixir-unicode/issues/2#issuecomment-252511607
		"""
		def half_width_length(s) do
			s
			|> String.graphemes
			|> Enum.map(fn grapheme ->
				case grapheme =~ ~r/^\p{Han}$/u do
					true  -> 2
					false -> 1
				end
			end)
			|> Enum.sum
		end

		@doc """
		Strips all ANSI escape codes from a string.
		"""
		def strip_ansi(s) do
			# Based on https://github.com/chalk/ansi-regex/blob/7c908e7b4eb6cd82bfe1295e33fdf6d166c7ed85/index.js
			s |> String.replace(~r/[\x{001b}\x{009b}][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-PRZcf-nqry=><]/, "")
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
		@doc ~S"""
		Takes a list of rows (themselves a list of columns containing only string
		values) and returns iodata containing an aligned ASCII table with `padding`
		spaces between each column.  Assumes that all characters are either all
		halfwidth or all fullwidth.

		Rows are allowed to contain a variable number of columns.  The last column
		in each row will not be padded.

		## Options

		  * `:padding`  - how many halfwidth spaces between columns (default: 1)
		  * `:width_fn` - a function called on each string to determine its width
		                  (default: &String.length/1).  Use this when the string
		                  contains ANSI escapes that must be stripped, or a mixture
		                  of halfwidth and fullwidth characters.

		## Implementation strategy

		  1. compute max width of each column
		  2. map each value to [value, padding] except last column
		     pad amount = (column width - value width) + padding
		  3. append \n to each row

		## Example

		    iex> format([[1, 2, 3], [4000, 6000, 9000]])
		    [[[["1", "    "], ["2", "    "], "3"], 10,
		      [["4000", " "], ["6000", " "], "9000"]], 10]
		"""
		def format(rows, opts \\ []) do
			padding  = Keyword.get(opts, :padding,  1)
			width_fn = Keyword.get(opts, :width_fn, &String.length/1)
			widths   = rows |> pad_short_rows |> transpose |> column_widths(width_fn)
			rows
			|> pad_cells(widths, padding, width_fn)
			|> Enum.map(&[&1, ?\n])
		end

		defp pad_cells(rows, column_widths, padding, width_fn) do
			Enum.map(rows, fn row ->
				map_special(
					Enum.zip(row, column_widths),
					# pad all values...
					fn {val, column_width} ->
						pad_amount = column_width - width_fn.(val) + padding
						[val, "" |> String.pad_leading(pad_amount)]
					end,
					# ...except the one in the last column
					fn {val, _width} -> val end
				)
			end)
		end

		defp column_widths(columns, width_fn) do
			Enum.map(columns, fn column ->
				column
				|> Enum.map(fn v ->
						if not is_binary(v) do
							raise(ArgumentError, "All values given to TableFormatter must be strings")
						end
						width_fn.(v)
					end)
				|> Enum.max
			end)
		end

		defp pad_short_rows(rows) do
			max_length = case rows |> Enum.map(&length/1) do
				[]    -> 0
				other -> Enum.max(other)
			end
			rows
			|> Enum.map(fn row ->
					row ++ List.duplicate("", max_length - length(row))
			end)
		end

		defp transpose(rows) do
			rows
			|> List.zip
			|> Enum.map(&Tuple.to_list/1)
		end

		# Map elements in `enumerable` with `fun1` except for the last element
		# which is mapped with `fun2`.
		defp map_special(enumerable,     fun1,  fun2), do: do_map_special(enumerable, [], fun1, fun2) |> :lists.reverse
		defp do_map_special([],   _acc, _fun1, _fun2), do: []
		defp do_map_special([t],   acc, _fun1,  fun2), do: [fun2.(t) | acc]
		defp do_map_special([h|t], acc,  fun1,  fun2), do: do_map_special(t, [fun1.(h) | acc], fun1, fun2)
	end
end
