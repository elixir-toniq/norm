defmodule Norm.Core.AllOf do
  @moduledoc false

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

      if result.error != [] do
        {:error, List.flatten(result.error)}
      else
        {:ok, Enum.at(result.ok, 0)}
      end
    end
  end
end

