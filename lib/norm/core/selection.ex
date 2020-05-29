defmodule Norm.Core.Selection do
  @moduledoc false
  # Provides the definition for selections

  defstruct required: [], schema: nil

  alias Norm.Core.Schema
  alias Norm.SpecError

  def new(schema, selectors) do
    # We're going to front load some work so that we can ensure that people are
    # requiring keys that actually exist in the schema and so that we can make
    # it easier to conform in the future.
    # select(schema, path, %{})
    case selectors do
      :all ->
        selectors = build_all_selectors(schema)
        select(selectors, schema)

      _ ->
        validate_selectors!(selectors)
        select(selectors, schema)
    end
  end

  def select(selectors, schema, required \\ [])
  def select([], schema, required), do: %__MODULE__{schema: schema, required: required}
  def select([selector | rest], schema, required) do
    case selector do
      {key, inner_keys} ->
        inner_schema = assert_spec!(schema, key)
        selection = select(inner_keys, inner_schema)
        select(rest, schema, [{key, selection} | required])

      key ->
        _ = assert_spec!(schema, key)
        select(rest, schema, [key | required])
    end
  end

  defp build_all_selectors(schema) do
    schema.specs
    |> Enum.map(fn
      {name, %Schema{}=inner_schema} -> {name, build_all_selectors(inner_schema)}
      {name, _} -> name
    end)
  end

  defp validate_selectors!([]), do: true
  defp validate_selectors!([{_key, inner} | rest]), do: validate_selectors!(inner) and validate_selectors!(rest)
  defp validate_selectors!([_key | rest]), do: validate_selectors!(rest)
  defp validate_selectors!(other), do: raise ArgumentError, "select expects a list of keys but received: #{inspect other}"

  defp assert_spec!(%Schema{}=schema, key) do
    case Schema.key_present?(schema, key) do
      false -> raise SpecError, {:selection, key, schema}
      true -> Schema.spec(schema, key)
    end
  end
  defp assert_spec!(%__MODULE__{}, _key) do
    # In the future we might support this and allow users to overwrite internal
    # selections. But for now its safer to forbid this.
    raise ArgumentError, """
    Attempting to specify a selection on top of another selection is
    not allowed.
    """
  end
  defp assert_spec!(other, _key) do
    raise ArgumentError, "Expected a schema and got: #{inspect other}"
  end

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer
    alias Norm.Conformer.Conformable

    def conform(_, input, path) when not is_map(input) do
      {:error, [Conformer.error(path, input, "not a map")]}
    end

    def conform(%{required: required, schema: schema}, input, path) do
      case Conformable.conform(schema, input, path) do
        {:ok, conformed} ->
          errors = ensure_keys(required, conformed, path, [])
          if Enum.any?(errors) do
            {:error, errors}
          else
            {:ok, conformed}
          end

        {:error, conforming_errors} ->
          errors = ensure_keys(required, input, path, [])
          {:error, conforming_errors ++ errors}
      end
    end

    defp ensure_keys([], _conformed, _path, errors), do: errors
    defp ensure_keys([{key, inner} | rest], conformed, path, errors) do
      case ensure_key(key, conformed, path) do
        :ok ->
          inner_value = Map.get(conformed, key)
          inner_errors = ensure_keys(inner.required, inner_value, path ++ [key], [])
          ensure_keys(rest, conformed, path, errors ++ inner_errors)

        error ->
          ensure_keys(rest, conformed, path, [error | errors])
      end
    end
    defp ensure_keys([key | rest], conformed, path, errors) do
      case ensure_key(key, conformed, path) do
        :ok ->
          ensure_keys(rest, conformed, path, errors)

        error ->
          ensure_keys(rest, conformed, path, [error | errors])
      end
    end

    defp ensure_key(_key, conformed, _path) when not is_map(conformed), do: :ok
    defp ensure_key(key, conformed, path) do
      if Map.has_key?(conformed, key) do
        :ok
      else
        Conformer.error(path ++ [key], conformed, ":required")
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Norm.Generatable do
      alias Norm.Generatable

      # In order to build a semantically meaningful selection we need to generate
      # all of the specified fields as well as the fields from the underlying
      # schema. We can then merge both of those maps together with the required
      # fields taking precedence.
      def gen(%{required: required, schema: schema}) do
        case Enum.reduce(required, %{}, & to_gen(&1, schema, &2)) do
          {:error, error} ->
            {:error, error}

          gen ->
            {:ok, StreamData.fixed_map(gen)}
        end
      end

      defp to_gen(_, _schema, {:error, error}), do: {:error, error}
      # If we're here than we're processing a key with an inner selection.
      defp to_gen({key, selection}, _schema, generator) do
        case Generatable.gen(selection) do
          {:ok, g} ->
            Map.put(generator, key, g)

          {:error, error} ->
            {:error, error}
        end
      end
      defp to_gen(key, schema, generator) do
        # Its safe to just get the spec because at this point we *know* that the
        # keys that have been selected are in the schema.
        with {:ok, g} <- Generatable.gen(Norm.Core.Schema.spec(schema, key)) do
          Map.put(generator, key, g)
        end
      end
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(selection, opts) do
      map = %{
        schema: selection.schema,
        required: selection.required
      }
      concat(["#Norm.Selection<", to_doc(map, opts), ">"])
    end
  end
end
