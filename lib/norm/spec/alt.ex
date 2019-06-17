defmodule Norm.Spec.Alt do
  @moduledoc false

  defstruct specs: []

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer.Conformable

  #   fn path, input ->
  #     results =
  #       opts
  #       |> Enum.map(fn {tag, spec} -> {tag, spec.(path ++ [tag], input)} end)

  #     good_result =
  #       results
  #       |> Enum.find(fn {_, {result, _}} -> result == :ok end)

  #     if good_result do
  #       {tag, {:ok, data}} = good_result
  #       {:ok, {tag, data}}
  #     else
  #       errors =
  #         results
  #         |> Enum.flat_map(fn {_, {_, errors}} -> errors end)

  #       {:error, errors}
  #     end
  #   end
    def conform(%{specs: specs}, input, path) do
      result =
        specs
        |> Enum.map(fn {name, spec} ->
          case Conformable.conform(spec, input, [name | path]) do
            {:ok, i} ->
              {:ok, {name, i}}

            {:error, errors} ->
              {:error, errors}
          end
        end)
        |> Enum.reduce(%{ok: [], error: []}, fn {result, s}, acc ->
          Map.put(acc, result, acc[result] ++ [s])
        end)

      if Enum.any?(result.ok) do
        {:ok, Enum.at(result.ok, 0)}
      else
        {:error, List.flatten(result.error)}
      end
    end
  end

  defimpl Norm.Generatable do
    def gen(%{specs: specs}) do
      case Enum.reduce(specs, [], &to_gen/2) do
        {:error, error} ->
          {:error, error}

        generators ->
          {:ok, StreamData.one_of(generators)}
      end
    end

    def to_gen(_, {:error, error}), do: {:error, error}
    def to_gen({_key, spec}, generators) do
      case Norm.Generatable.gen(spec) do
        {:ok, g} ->
          [g | generators]

        {:error, error} ->
          {:error, error}
      end
    end
  end
end

