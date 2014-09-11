defmodule HashRing.Mixfile do
  use Mix.Project

  def project do
    [
      app: :hash_ring_ex,
      version: "1.1.1",
      elixir: "~> 1.0.0",
      description: description,
      package: package,
      deps: deps,
      compilers: [:yecc, :leex, :rebar, :erlang, :elixir, :app]
    ]
  end

  def application do
    [applications: []]
  end

  defp deps do
    []
  end

  defp description do
    """
    A consistent hash-ring implemention for Elixir.
    """
  end

  defp package do
    [
      contributors: ["Jamie Winsor"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/reset/hash-ring-ex"},
      files: ["lib", "mix.exs", "README*", "LICENSE", "rebar*"]
    ]
  end
end

defmodule Mix.Tasks.Compile.Rebar do
  use Mix.Task

  def run(_) do
    Mix.shell.cmd "./rebar g-d"
    Mix.shell.cmd "./rebar co"
  end
end
