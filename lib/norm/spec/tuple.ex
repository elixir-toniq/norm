defmodule Norm.Spec.Tuple do
  defstruct args: []

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer
    alias Norm.Conformer.Conformable

    def conform(%{args: as}, input, path) when is_tuple(input) and (length(as) != tuple_size(input)) do
      {:error, [Conformer.error(path, input, "incorrect tuple size")]}
    end

    def conform(%{args: args}, input, path) do
      results =
        args
        |> Enum.with_index()
        |> Enum.map(fn {spec, i} -> Conformable.conform(spec, elem(input, i), path ++ [i]) end)
        |> Conformer.group_results

      if Enum.any?(results.error) do
        {:error, results.error}
      else
        {:ok, List.to_tuple(results.ok)}
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Norm.Generatable do
      alias Norm.Generatable

      def gen(%{args: as}) do
        with list when is_list(list) <- Enum.reduce(as, [], &to_gen/2) do
          # The list we build is in reverse order so we need to reverse first
          generator =
            list
            |> Enum.reverse
            |> List.to_tuple
            |> StreamData.tuple()

          {:ok, generator}
        end
      end

      def to_gen(_, {:error, error}), do: {:error, error}
      def to_gen(spec, generator) do
        with {:ok, g} <- Generatable.gen(spec) do
          [g | generator]
        end
      end
    end
  end
end

