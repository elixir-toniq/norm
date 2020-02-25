defmodule Norm.Core.Spec.Or do
  @moduledoc false

  defstruct [:left, :right]

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer.Conformable, as: Conform

    def conform(%{left: l, right: r}, input, path) do
      case Conform.conform(l, input, path) do
        {:ok, input} ->
          {:ok, input}

        {:error, l_errors} ->
          case Conform.conform(r, input, path) do
            {:ok, input} ->
              {:ok, input}

            {:error, r_errors} ->
              {:error, l_errors ++ r_errors}
          end
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Norm.Generatable do
      alias Norm.Generatable

      def gen(%{left: l, right: r}) do
        with {:ok, l} <- Generatable.gen(l),
             {:ok, r} <- Generatable.gen(r) do
          {:ok, StreamData.one_of([l, r])}
        end
      end
    end
  end

  @doc false
  def __inspect__(%{left: left, right: right}) do
    left = left.__struct__.__inspect__(left)
    right = right.__struct__.__inspect__(right)
    Inspect.Algebra.concat([left, " or ", right])
  end

  defimpl Inspect do
    def inspect(struct, _) do
      Inspect.Algebra.concat(["#Norm.Spec<", @for.__inspect__(struct), ">"])
    end
  end
end
