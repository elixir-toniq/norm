defmodule Norm.Core.Spec.And do
  @moduledoc false

  alias Norm.Core.Spec
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
      with {:ok, _} <- Conformable.conform(l, input, path) do
        Conformable.conform(r, input, path)
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

  @doc false
  def __inspect__(%{left: left, right: right}) do
    left = left.__struct__.__inspect__(left)
    right = right.__struct__.__inspect__(right)
    Inspect.Algebra.concat([left, " and ", right])
  end

  defimpl Inspect do
    def inspect(struct, _) do
      Inspect.Algebra.concat(["#Norm.Spec<", @for.__inspect__(struct), ">"])
    end
  end
end
