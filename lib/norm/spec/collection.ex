defmodule Norm.Spec.Collection do
  @moduledoc false

  defstruct spec: nil, opts: [kind: :list]

  def new(spec, opts) do
    %__MODULE__{spec: spec, opts: opts}
  end

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer
    alias Norm.Conformer.Conformable

    def conform(%{spec: spec, opts: opts}, input, path) do
      results =
        input
        |> Enum.map(&Conformable.conform(spec, &1, path))
        |> Conformer.group_results()

      if Enum.any?(results.error) do
        {:error, results.error}
      else
        {:ok, convert(results.ok, opts[:kind])}
      end
    end

    defp convert(results, :map) do
      Enum.into(results, %{})
    end

    defp convert(results, _) do
      results
    end
  end
end
