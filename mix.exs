defmodule Gears.Mixfile do
	use Mix.Project

	def project do
		[
			app: :gears,
			version: "0.7.0",
			elixir: "~> 1.4",
			build_embedded: Mix.env == :prod,
			start_permanent: Mix.env == :prod,
			deps: deps()
		]
	end

	defp deps do
		[{:pipe_here, ">= 1.0.0"}]
	end
end
