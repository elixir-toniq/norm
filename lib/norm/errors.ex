defmodule Norm.MismatchError do
  defexception [:message]

  def exception(errors) do
    msg =
      errors
      |> Enum.map(&Norm.Conformer.error_to_msg/1)
      |> Enum.join("\n")

    %__MODULE__{message: "Could not conform input:\n" <> msg}
  end
end

defmodule Norm.GeneratorLibraryError do
  defexception [:message]

  def exception(_) do
    %__MODULE__{
      message: "In order to use generators please include `stream_data` as a dependency"
    }
  end
end

defmodule Norm.GeneratorError do
  defexception [:message]

  def exception(predicate) do
    msg = "Unable to create a generator for: #{predicate}"
    %__MODULE__{message: msg}
  end
end

defmodule Norm.SpecError do
  defexception [:message]
  alias Norm.Core.Spec
  alias Norm.Core.Schema
  alias Norm.Core.Collection
  alias Norm.Core.Alt
  alias Norm.Core.AnyOf

  def exception(details) do
    %__MODULE__{message: msg(details)}
  end

  defp msg({:selection, key, schema}) do
    """
    key: #{format(key)} was not found in schema:
    #{format(schema)}
    """
  end

  defp format(val, indentation \\ 0)

  defp format({key, spec_or_schema}, i) do
    "{" <> format(key, i) <> ", " <> format(spec_or_schema, i + 1) <> "}"
  end
  defp format(atom, _) when is_atom(atom), do: ":#{atom}"
  defp format(str, _) when is_binary(str), do: ~s|"#{str}"|
  defp format(%Spec{}=s, _), do: inspect(s)
  defp format(%Spec.And{}=s, _), do: inspect(s)
  defp format(%Spec.Or{}=s, _), do: inspect(s)
  defp format(%Schema{specs: specs}, i) do
    f = fn {key, spec_or_schema}, i ->
      format(key, i) <> " => " <> format(spec_or_schema, i + 1)
    end

    specs =
      specs
      |> Enum.map(& f.(&1, i))
      |> Enum.map(&pad(&1, (i + 1) * 2))
      |> Enum.join("\n")

    "%{\n" <> specs <> "\n" <> pad("}", i * 2)
  end
  defp format(%Collection{spec: spec}, i) do
    "coll_of(#{format(spec, i)})"
  end
  defp format(%Alt{specs: specs}, i) do
    formatted =
      specs
      |> Enum.map(&format(&1, i))
      |> Enum.map(&pad(&1, (i + 1) * 2))
      |> Enum.join("\n")

    if length(specs) > 0 do
      "alt([\n#{formatted}\n" <> pad("])", i * 2)
    else
      "alt([])"
    end
  end
  defp format(%AnyOf{specs: specs}, i) do
    formatted =
      specs
      |> Enum.map(&format(&1, i))
      |> Enum.map(&pad(&1, (i + 1) * 2))
      |> Enum.join("\n")

    if length(specs) > 0 do
      "one_of([\n#{formatted}\n" <> pad("])", i * 2)
    else
      "one_of([])"
    end
  end
  defp format(val, _i) do
    inspect(val)
  end

  defp pad(str, 0), do: str
  defp pad(str, i), do: " " <> pad(str, i - 1)
end
