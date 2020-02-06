defmodule Norm.Core.Collection do
  @moduledoc false

  defstruct spec: nil, opts: []

  def new(spec, opts) do
    %__MODULE__{spec: spec, opts: opts}
  end

  defimpl Norm.Conformer.Conformable do
    alias Norm.Conformer
    alias Norm.Conformer.Conformable

    def conform(%{spec: spec, opts: opts}, input, path) do
      with :ok <- check_enumerable(input, path, opts),
           :ok <- check_kind_of(input, path, opts),
           :ok <- check_distinct(input, path, opts),
           :ok <- check_counts(input, path, opts) do
        results =
          input
          |> Enum.with_index()
          |> Enum.map(fn {elem, i} -> Conformable.conform(spec, elem, path ++ [i]) end)
          |> Conformer.group_results()

        into = cond do
          opts[:into] ->
            opts[:into]

          is_list(input) ->
            []

          is_map(input) and Map.has_key?(input, :__struct__) ->
            struct(input.__struct__)

          is_map(input) ->
            %{}

          true ->
            raise ArgumentError, "Cannot determine output type for collection"
        end

        if Enum.any?(results.error) do
          {:error, results.error}
        else
          {:ok, convert(results.ok, into)}
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

    defp check_enumerable(input, path, _opts) do
      if Enumerable.impl_for(input) == nil do
        {:error, [Conformer.error(path, input, "not enumerable")]}
      else
        :ok
      end
    end

    defp check_kind_of(input, path, opts) do
      cond do
        # If kind is nil we assume it doesn't matter
        opts[:kind] == nil ->
          :ok

        # If we have a `:kind` and it returns true we pass the spec
        opts[:kind].(input) ->
          :ok

        # Otherwise return an error
        true ->
          {:error, [Conformer.error(path, input, "does not match kind: #{inspect opts[:kind]}")]}
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
          # We assume that if we don't have an `into` specified then its a list
          StreamData.constant(Enum.into(list, opts[:into] || []))
        end)
      end
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(coll_of, opts) do
      concat(["#Norm.CollOf<", to_doc(coll_of.spec, opts), ">"])
    end
  end
end
