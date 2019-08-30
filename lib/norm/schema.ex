defmodule Norm.Schema do
  @moduledoc false
  # Provides the definition for schemas

  alias __MODULE__

  defstruct specs: [], struct: nil

  # If we're building a schema from a struct then we need to add a default spec
  # for each key that only checks for presence. This allows users to specify
  # struct types without needing to specify specs for each key
  def build(%{__struct__: name}=struct) do
    specs =
      struct
      |> Map.from_struct
      |> Enum.to_list()

    %Schema{specs: specs, struct: name}
  end

  def build(map) when is_map(map) do
    specs =
      map
      |> Enum.to_list()

    %Schema{specs: specs}
  end

  def spec(schema, key) do
    schema.specs
    |> Enum.filter(fn {name, _} -> name == key end)
    |> Enum.map(fn {_, spec} -> spec end)
    |> Enum.at(0)
  end

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer.Conformable

    def conform(_, input, path) when not is_map(input) do
      {:error, [error(path, input, "not a map")]}
    end

    def conform(%{specs: specs, struct: target}, input, path) when not is_nil(target) do
      # Ensure we're mapping the correct struct
      if Map.get(input, :__struct__) == target do
        with {:ok, conformed} <- check_specs(specs, input, path) do
          {:ok, struct(target, conformed)}
        end
      else
        short_name =
          target
          |> Atom.to_string
          |> String.replace("Elixir.", "")

        {:error, [error(path, input, "#{short_name}")]}
      end
    end

    def conform(%Norm.Schema{specs: specs}, input, path) do
      check_specs(specs, input, path)
    end

    defp check_specs(specs, input, path) do
      results =
        specs
        |> Enum.map(& check_spec(&1, input, path))
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

    defp check_spec({key, nil}, input, path) do
      case Map.has_key?(input, key) do
        false ->
          {key, {:error, [error(path ++ [key], input, ":required")]}}

        true ->
          {key, {:ok, Map.get(input, key)}}
      end
    end
    defp check_spec({key, spec}, input, path) do
      val = Map.get(input, key)

      if val == nil do
        {key, {:error, [error(path ++ [key], input, ":required")]}}
      else
        {key, Conformable.conform(spec, val, path ++ [key])}
      end
    end

    defp error(path, input, msg) do
      %{path: path, input: input, msg: msg, at: nil}
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
end
