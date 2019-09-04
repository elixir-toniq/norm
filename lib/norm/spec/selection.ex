defmodule Norm.Spec.Selection do
  @moduledoc false
  # Provides the definition for selections

  defstruct subset: nil

  alias Norm.Schema
  alias Norm.SpecError

  def new(schema, path) do
    select(schema, path, %{})
  end

  defp select(_, [], selection), do: %__MODULE__{subset: selection}

  defp select(schema, [selector | rest], selection) do
    case selector do
      {key, inner} ->
        case Schema.spec(schema, key) do
          nil ->
            raise SpecError, {:selection, key, schema}

          inner_schema ->
            selection = Map.put(selection, key, select(inner_schema, inner, %{}))
            select(schema, rest, selection)
        end

      key ->
        case Schema.spec(schema, key) do
          nil ->
            raise SpecError, {:selection, key, schema}

          spec ->
            new_selection = Map.put(selection, key, spec)
            select(schema, rest, new_selection)
        end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Norm.Generatable do
      alias Norm.Generatable

      def gen(%{subset: specs}) do
        case Enum.reduce(specs, %{}, &to_gen/2) do
          {:error, error} ->
            {:error, error}

          gen ->
            {:ok, StreamData.fixed_map(gen)}
        end
      end

      defp to_gen(_, {:error, error}), do: {:error, error}

      defp to_gen({key, spec}, generator) do
        case Generatable.gen(spec) do
          {:ok, g} ->
            Map.put(generator, key, g)

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer.Conformable

    def conform(%{subset: subset}, input, path) do
      results =
        subset
        |> Enum.map(fn {key, spec} ->
          val = Map.get(input, key)

          if val do
            {key, Conformable.conform(spec, val, path ++ [key])}
          else
            {key, {:error, [error(path ++ [key], input, ":required")]}}
          end
        end)
        |> Enum.reduce(%{ok: [], error: []}, fn {key, {result, r}}, acc ->
          Map.put(acc, result, [{key, r} | acc[result]])
        end)

      if Enum.any?(results.error) do
        errors =
          results.error
          |> Enum.flat_map(fn {_, errors} -> errors end)

        {:error, errors}
      else
        {:ok, Enum.into(results.ok, %{})}
      end
    end

    defp error(path, input, msg) do
      %{path: path, input: input, msg: msg, at: nil}
    end
  end
end
