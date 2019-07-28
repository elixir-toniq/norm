defmodule Norm.Spec.And do
  @moduledoc false

  defstruct [:left, :right]

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer.Conformable

    def conform(%{left: l, right: r}, input, path) do
      errors =
        [l, r]
        |> Enum.map(fn spec -> Conformable.conform(spec, input, path) end)
        |> Enum.filter(fn {result, _} -> result == :error end)
        |> Enum.flat_map(fn {_, msg} -> msg end)

      if Enum.any?(errors) do
        {:error, errors}
      else
        {:ok, input}
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Norm.Generatable do
      alias Norm.Generatable

      def gen(%{left: l, right: r}) do
        with {:ok, gen} <- Generatable.gen(l) do
          {:ok, StreamData.filter(gen, r.f)}
        end
      end
    end
  end
end

