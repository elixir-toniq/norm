defmodule Norm.Generator do
  @moduledoc false
  # This module provides a wrapper struct for overriding generators of the other
  # conformable and generatable types.

  defstruct ~w|conformer generator|a

  def new(conformer, generator) do
    %__MODULE__{conformer: conformer, generator: generator}
  end

  defimpl Norm.Conformer.Conformable do
    # We just pass the conformer through here. We don't need to be involved.
    def conform(%{conformer: c}, input, path) do
      Norm.Conformer.Conformable.conform(c, input, path)
    end
  end

  defimpl Norm.Generatable do
    def gen(%{generator: gen}) do
      if gen == :null do
        raise Norm.GeneratorLibraryError
      else
        {:ok, gen}
      end
    end
  end
end
