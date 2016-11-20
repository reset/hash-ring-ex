defmodule HashRing.Mixfile do
  use Mix.Project

  def project do
    [
      app: :hash_ring_ex,
      version: "1.1.2",
      elixir: "~> 1.1",
      description: description,
      package: package,
      deps: deps,
      compilers: Mix.compilers ++ [:copy_lib]
    ]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [
      {:hash_ring, github: "chrismoos/hash-ring"}
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
      links: %{"GitHub" => "https://github.com/reset/hash-ring-ex"},
      files: ["lib", "mix.exs", "README*", "LICENSE", "rebar*"]
    ]
  end
end

defmodule Mix.Tasks.Compile.CopyLib do
  use Mix.Task

  def run(_) do
    priv = :code.priv_dir(:hash_ring_ex)

    File.mkdir_p!(priv)

    hr_priv = :code.priv_dir(:hash_ring)

    File.ls!(hr_priv)
    |> Enum.filter(&(String.ends_with?(&1, ".so")))
    |> Enum.each(fn (filename) ->
      source_path = Path.join(hr_priv, filename)
      dest_path = Path.join(priv, filename)
      File.cp!(source_path, dest_path)
    end)
  end
end
