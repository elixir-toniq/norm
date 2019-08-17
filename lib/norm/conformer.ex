defmodule Norm.Conformer do
  @moduledoc false
  # This module provides an api for conforming values and a protocol for
  # conformable types

  def conform(spec, input) do
    # If we get errors then we should convert them to messages. Otherwise
    # we just let good results fall through.
    with {:error, errors} <- Norm.Conformer.Conformable.conform(spec, input, []) do
      {:error, Enum.map(errors, &error_to_msg/1)}
    end
  end

  def group_results(results) do
    results
    |> Enum.reduce(%{ok: [], error: []}, fn {result, s}, acc ->
      Map.put(acc, result, acc[result] ++ [s])
    end)
    |> update_in([:ok], & List.flatten(&1))
    |> update_in([:error], & List.flatten(&1))
  end

  def error(path, input, msg) do
    %{path: path, input: input, msg: msg, at: nil}
  end

  def error_to_msg(%{path: path, input: input, msg: msg}) do
    path  = if path == [], do: nil, else: "in: " <> build_path(path)
    val   = "val: #{format_val(input)}"
    fails = "fails: #{msg}"

    [val, fails, path]
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
  defp format_val(val) when is_map(val), do: inspect val
  defp format_val({:index, i}), do: "[#{i}]"
  defp format_val(t) when is_tuple(t), do: "#{inspect t}"
  defp format_val(msg), do: "#{msg}"


  defprotocol Conformable do
    @moduledoc false
    # Defines a conformable type. Must take the type, current path, and input and
    # return an success tuple with the conformed data or a list of errors.

    def conform(spec, path, input)
  end
end


