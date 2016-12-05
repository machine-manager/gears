defmodule Gears.Mixfile do
	use Mix.Project

	def project do
		[
			app: :gears,
			version: "0.4.0",
			elixir: "~> 1.4-dev",
			build_embedded: Mix.env == :prod,
			start_permanent: Mix.env == :prod,
			deps: deps()
		]
	end

	defp deps do
		[]
	end
end
