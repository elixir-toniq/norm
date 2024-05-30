defmodule Norm.MixProject do
  use Mix.Project

  @version "0.13.0"
  @source_url "https://github.com/elixir-toniq/norm"

  def project do
    [
      app: :norm,
      version: @version,
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "Norm",
      source_url: @source_url,
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      env: [enable_contracts: true]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 0.6 or ~> 1.0", optional: true},
      {:ex_doc, "~> 0.19", only: [:dev, :test]}
    ]
  end

  def description do
    """
    Norm is a system for specifying the structure of data. It can be used for
    validation and for generation of data. Norm does not provide any set of
    predicates and instead allows you to re-use any of your existing
    validations.
    """
  end

  def package do
    [
      name: "norm",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  def docs do
    [
      source_ref: "v#{@version}",
      source_url: @source_url,
      main: "Norm"
    ]
  end
end
