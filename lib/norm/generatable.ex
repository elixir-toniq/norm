defprotocol Norm.Generatable do
  @moduledoc false
  # Defines generatable types

  def gen(able)
end

if Code.ensure_loaded?(StreamData) do
  defimpl Norm.Generatable, for: Atom do
    def gen(atom) do
      {:ok, StreamData.constant(atom)}
    end
  end

  defimpl Norm.Generatable, for: Tuple do
    alias Norm.Generatable

    def gen(tuple) do
      elems = Tuple.to_list(tuple)

      with list when is_list(list) <- Enum.reduce(elems, [], &to_gen/2) do
        # The list we build is in reverse order so we need to reverse first
        generator =
          list
          |> Enum.reverse()
          |> List.to_tuple()
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
