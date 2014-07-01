defmodule HashRing.Mixfile do
  use Mix.Project

  def project do
    [app: :hash_ring_ex,
     version: "1.0.0",
     elixir: "~> 0.13",
     description: description,
     package: package,
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [
      {:hash_ring, github: "chrismoos/hash-ring"},
    ]
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
      links: %{"GitHub" => "https://github.com/reset/hash-ring-ex"}
    ]
  end
end
