defmodule Norm.Core.Alt do
  @moduledoc false

  defstruct specs: []

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer
    alias Norm.Conformer.Conformable

    def conform(%{specs: specs}, input, path) do
      result =
        specs
        |> Enum.map(fn {name, spec} ->
          case Conformable.conform(spec, input, path ++ [name]) do
            {:ok, i} ->
              {:ok, {name, i}}

            {:error, errors} ->
              {:error, errors}
          end
        end)
        |> Conformer.group_results()

      if Enum.any?(result.ok) do
        {:ok, Enum.at(result.ok, 0)}
      else
        {:error, List.flatten(result.error)}
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Norm.Generatable do
      def gen(%{specs: specs}) do
        case Enum.reduce(specs, [], &to_gen/2) do
          {:error, error} ->
            {:error, error}

          generators ->
            {:ok, StreamData.one_of(generators)}
        end
      end

      def to_gen(_, {:error, error}), do: {:error, error}

      def to_gen({_key, spec}, generators) do
        case Norm.Generatable.gen(spec) do
          {:ok, g} ->
            [g | generators]

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(alt, opts) do
      concat(["#Norm.Alt<", to_doc(alt.specs, opts), ">"])
    end
  end
end
