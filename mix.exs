defmodule ExTelegram.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_telegram,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExTelegram.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tdlib, git: "https://github.com/prtngn/ex_tdlib", branch: "nightly"},
      {:styler, "~> 0.10", only: [:dev, :test], runtime: false}
    ]
  end
end
