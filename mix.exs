defmodule HashRing.Mixfile do
  use Mix.Project

  def project do
    [app: :hash_ring_ex,
     version: "0.0.1",
     elixir: "~> 0.13",
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
end
