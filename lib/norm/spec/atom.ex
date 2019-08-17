defmodule Norm.Spec.Atom do
  defstruct [:atom]

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer

    def conform(%{atom: atom}, input, path) do
      cond do
        not is_atom(input) ->
          {:error, [Conformer.error(path, input, "is not an atom.")]}

        atom != input ->
          {:error, [Conformer.error(path, input, "== :#{atom}")]}

        true ->
          {:ok, atom}
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Norm.Generatable do
      def gen(%{atom: a}) do
        {:ok, StreamData.constant(a)}
      end
    end
  end
end
