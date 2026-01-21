defprotocol Norm.Coerceable do
  @moduledoc false

  def coerce(spec, input)
end

defimpl Norm.Coerceable, for: Norm.Core.Schema do
  require Norm

  def coerce(%{specs: specs}, input) when is_map(input) do
    specs
    |> Enum.map(fn {key, spec} ->
      cond do
        is_atom(key) ->
          case Enum.find(input, fn {k, v} -> Atom.to_string(key) == k || k == key end) do
            {k, v} -> {Norm.Coerceable.coerce(Norm.spec(is_atom), k), Norm.Coerceable.coerce(spec, v)}
          end
      end
    end)
    |> Enum.into(%{})
  end
end

defimpl Norm.Coerceable, for: Norm.Core.Spec do
  def coerce(%{f: f, generator: gen}, input) do
    sym_to_coercer(gen, input)
  end

  defp sym_to_coercer(:is_atom, input) do
    :"#{input}"
  end

  defp sym_to_coercer(:is_binary, input) do
    "#{input}"
  end

  defp sym_to_coercer(:is_bitstring, input) do
    "#{input}"
  end

  defp sym_to_coercer(:is_boolean, input) do
    case input do
      "true" -> true
      "false" -> false
    end
  end

  defp sym_to_coercer(:is_float, input) do
    cond do
      is_binary(input) -> String.to_float(input)
      is_integer(input) -> input / 1
    end
  end

  defp sym_to_coercer(:is_integer, input) do
    cond do
      is_binary(input) -> String.to_integer(input)
      is_float(input) -> round(input)
    end
  end

  defp sym_to_coercer(:is_nil, input) do
    case input do
      "null" -> nil
      "nil" -> nil
    end
  end

  defp sym_to_coercer(:is_number, input) do
    cond do
      is_binary(input) -> String.to_integer(input)
      is_float(input) -> round(input)
      is_integer(input) -> input
    end
  end

  # defp sym_to_coercer(:is_list, input) do
  # end

  defp sym_to_coercer(gen, input) do
    input
    # default
  end
end
