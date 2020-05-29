defmodule Norm.Core.Schema do
  @moduledoc false
  # Provides the definition for schemas

  alias __MODULE__

  defstruct specs: %{}, struct: nil

  def build(%{__struct__: name} = struct) do
    # If we're building a schema from a struct then we need to reject any keys with
    # values that don't implement the conformable protocol. This allows users to specify
    # struct types without needing to specify specs for each key
    specs =
      struct
      |> Map.from_struct()
      |> Enum.reject(fn {_, value} -> Norm.Conformer.Conformable.impl_for(value) == nil end)
      |> Enum.into(%{})

    %Schema{specs: specs, struct: name}
  end

  def build(map) when is_map(map) do
    %Schema{specs: map}
  end

  def spec(schema, key) do
    schema.specs
    |> Enum.filter(fn {name, _} -> name == key end)
    |> Enum.map(fn {_, spec} -> spec end)
    |> Enum.at(0)
  end

  def key_present?(schema, key) do
    schema.specs
    |> Enum.any?(fn {name, _} -> name == key end)
  end

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer
    alias Norm.Conformer.Conformable

    def conform(_, input, path) when not is_map(input) do
      {:error, [Conformer.error(path, input, "not a map")]}
    end

    # Conforming a struct
    def conform(%{specs: specs, struct: target}, input, path) when not is_nil(target) do
      # Ensure we're mapping the correct struct
      cond do
        Map.get(input, :__struct__) != target ->
          short_name =
            target
            |> Atom.to_string()
            |> String.replace("Elixir.", "")

          {:error, [Conformer.error(path, input, "#{short_name}")]}

        true ->
          with {:ok, conformed} <- check_specs(specs, Map.from_struct(input), path) do
            {:ok, struct(target, conformed)}
          end
      end
    end

    # conforming a map.
    def conform(%Schema{specs: specs}, input, path) do
      if Map.get(input, :__struct__) != nil do
        with {:ok, conformed} <- check_specs(specs, Map.from_struct(input), path) do
          {:ok, struct(input.__struct__, conformed)}
        end
      else
        check_specs(specs, input, path)
      end
    end

    defp check_specs(specs, input, path) do
      results =
        input
        |> Enum.map(&check_spec(&1, specs, path))
        |> Enum.reduce(%{ok: [], error: []}, fn {key, {result, conformed}}, acc ->
          Map.put(acc, result, acc[result] ++ [{key, conformed}])
        end)

      errors =
        results.error
        |> Enum.flat_map(fn {_, error} -> error end)

      if Enum.any?(errors) do
        {:error, errors}
      else
        {:ok, Enum.into(results.ok, %{})}
      end
    end

    defp check_spec({key, value}, specs, path) do
      case Map.get(specs, key) do
        nil ->
          {key, {:ok, value}}

        spec ->
          {key, Conformable.conform(spec, value, path ++ [key])}
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Norm.Generatable do
      alias Norm.Generatable

      def gen(%{struct: target, specs: specs}) do
        case Enum.reduce(specs, %{}, &to_gen/2) do
          {:error, error} ->
            {:error, error}

          generator ->
            to_streamdata(generator, target)
        end
      end

      defp to_streamdata(generator, nil) do
        {:ok, StreamData.fixed_map(generator)}
      end

      defp to_streamdata(generator, target) do
        sd =
          generator
          |> StreamData.fixed_map()
          |> StreamData.bind(fn map -> StreamData.constant(struct(target, map)) end)

        {:ok, sd}
      end

      def to_gen(_, {:error, error}), do: {:error, error}

      def to_gen({key, spec}, generator) do
        case Generatable.gen(spec) do
          {:ok, g} ->
            Map.put(generator, key, g)

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(schema, opts) do
      map = if schema.struct do
        struct(schema.struct, schema.specs)
      else
        schema.specs
      end
      concat(["#Norm.Schema<", to_doc(map, opts), ">"])
    end
  end
end
