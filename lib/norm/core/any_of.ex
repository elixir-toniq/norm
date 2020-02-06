defmodule Norm.Core.AnyOf do
  @moduledoc false
  # Provides the struct for unions of specifications

  defstruct specs: []

  def new(specs) do
    %__MODULE__{specs: specs}
  end

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer
    alias Norm.Conformer.Conformable

    def conform(%{specs: specs}, input, path) do
      result =
        specs
        |> Enum.map(fn spec -> Conformable.conform(spec, input, path) end)
        |> Conformer.group_results()

      if result.ok != [] do
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

      def to_gen(spec, generators) do
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

    def inspect(union, opts) do
      concat(["#Norm.OneOf<", to_doc(union.specs, opts), ">"])
    end
  end
end
