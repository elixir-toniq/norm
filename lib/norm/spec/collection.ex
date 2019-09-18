defmodule Norm.Spec.Collection do
  @moduledoc false

  defstruct spec: nil, opts: []

  def new(spec, opts) do
    %__MODULE__{spec: spec, opts: opts}
  end

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer
    alias Norm.Conformer.Conformable

    def conform(%{spec: spec, opts: opts}, input, path) do
      with :ok <- check_distinct(input, path, opts),
           :ok <- check_counts(input, path, opts) do
        results =
          input
          |> Enum.with_index()
          |> Enum.map(fn {elem, i} -> Conformable.conform(spec, elem, path ++ [i]) end)
          |> Conformer.group_results()

        if Enum.any?(results.error) do
          {:error, results.error}
        else
          {:ok, convert(results.ok, opts[:into])}
        end
      end
    end

    defp convert(results, type) do
      Enum.into(results, type)
    end

    defp check_counts(input, path, opts) do
      min = opts[:min_count]
      max = opts[:max_count]
      length = Enum.count(input)

      cond do
        min > length ->
          {:error, [Conformer.error(path, input, "min_count: #{min}")]}

        max < length ->
          {:error, [Conformer.error(path, input, "max_count: #{max}")]}

        true ->
          :ok
      end
    end

    defp check_distinct(input, path, opts) do
      if opts[:distinct] do
        if Enum.uniq(input) == input do
          :ok
        else
          {:error, [Conformer.error(path, input, "distinct?")]}
        end
      else
        :ok
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Norm.Generatable do
      def gen(%{spec: spec, opts: opts}) do
        with {:ok, g} <- Norm.Generatable.gen(spec) do
          generator =
            g
            |> sequence(opts)
            |> into(opts)

          {:ok, generator}
        end
      end

      def sequence(g, opts) do
        min = opts[:min_count]
        max = opts[:max_count]

        if opts[:distinct] do
          StreamData.uniq_list_of(g, [min_length: min, max_length: max])
        else
          StreamData.list_of(g, [min_length: min, max_length: max])
        end
      end

      def into(list_gen, opts) do
        StreamData.bind(list_gen, fn list ->
          StreamData.constant(Enum.into(list, opts[:into]))
        end)
      end
    end
  end
end
