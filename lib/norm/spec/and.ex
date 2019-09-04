defmodule Norm.Spec.And do
  @moduledoc false

  alias Norm.Spec
  alias __MODULE__

  defstruct [:left, :right]

  def new(l, r) do
    case {l, r} do
      {%Spec{}, %Spec{}} ->
        %__MODULE__{left: l, right: r}

      {%And{}, %Spec{}} ->
        %__MODULE__{left: l, right: r}

      _ ->
        raise ArgumentError, "both sides of an `and` must be a predicate"
    end
  end

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
