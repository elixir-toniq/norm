defmodule Norm.Conformer do
  @moduledoc false
  # This module provides an api for conforming values and a protocol for
  # conformable types

  def conform(spec, input) do
    Norm.Conformer.Conformable.conform(spec, input, [])
  end

  def group_results(results) do
    results
    |> Enum.reduce(%{ok: [], error: []}, fn {result, s}, acc ->
      Map.put(acc, result, acc[result] ++ [s])
    end)
    |> update_in([:error], &List.flatten(&1))
  end

  def error(path, input, msg) do
    %{path: path, input: input, spec: msg}
  end

  def error_to_msg(%{path: path, input: input, spec: msg}) do
    path = if path == [], do: nil, else: "in: " <> build_path(path)
    val = "val: #{format_val(input)}"
    fails = "fails: #{msg}"

    [val, path, fails]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp build_path(keys) do
    keys
    |> Enum.map(&format_val/1)
    |> Enum.join("/")
  end

  defp format_val(nil), do: "nil"
  defp format_val(msg) when is_binary(msg), do: "\"#{msg}\""
  defp format_val(msg) when is_boolean(msg), do: "#{msg}"
  defp format_val(msg) when is_atom(msg), do: ":#{msg}"
  defp format_val(val) when is_map(val), do: inspect(val)
  defp format_val({:index, i}), do: "[#{i}]"
  defp format_val(t) when is_tuple(t), do: "#{inspect(t)}"
  defp format_val(l) when is_list(l), do: "#{inspect(l)}"

  defp format_val(msg), do: inspect(msg)

  defprotocol Conformable do
    @moduledoc false
    # Defines a conformable type. Must take the type, current path, and input and
    # return an success tuple with the conformed data or a list of errors.

    # @fallback_to_any true
    def conform(spec, path, input)
  end
end

# defimpl Norm.Conformer.Conformable, for: Any do
#   def conform(_thing, input, _path) do
#     {:ok, input}
#   end
# end

defimpl Norm.Conformer.Conformable, for: Atom do
  alias Norm.Conformer

  def conform(atom, input, path) do
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

defimpl Norm.Conformer.Conformable, for: Tuple do
  alias Norm.Conformer
  alias Norm.Conformer.Conformable

  def conform(spec, input, path) when is_tuple(input) and tuple_size(spec) != tuple_size(input) do
    {:error, [Conformer.error(path, input, "incorrect tuple size")]}
  end

  def conform(_spec, input, path) when not is_tuple(input) do
    {:error, [Conformer.error(path, input, "not a tuple")]}
  end

  def conform(spec, input, path) do
    results =
      spec
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.map(fn {spec, i} -> Conformable.conform(spec, elem(input, i), path ++ [i]) end)
      |> Conformer.group_results()

    if Enum.any?(results.error) do
      {:error, results.error}
    else
      {:ok, List.to_tuple(results.ok)}
    end
  end
end
