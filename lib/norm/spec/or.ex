defmodule Norm.Spec.Or do
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
end
