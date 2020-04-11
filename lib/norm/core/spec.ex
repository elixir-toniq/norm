defmodule Norm.Core.Spec do
  @moduledoc false
  # Provides a struct to encapsulate specs

  alias __MODULE__

  alias Norm.Core.Spec.{
    And,
    Or
  }

  defstruct predicate: nil, generator: nil, f: nil

  def build({:or, _, [left, right]}) do
    l = build(left)
    r = build(right)

    quote do
      %Or{left: unquote(l), right: unquote(r)}
    end
  end

  def build({:and, _, [left, right]}) do
    l = build(left)
    r = build(right)

    quote do
      And.new(unquote(l), unquote(r))
    end
  end

  # Anonymous functions
  def build(quoted = {f, _, _args}) when f in [:&, :fn] do
    predicate = Macro.to_string(quoted)

    quote do
      run = fn input ->
        input |> unquote(quoted).()
      end

      %Spec{generator: nil, predicate: unquote(predicate), f: run}
    end
  end

  # Standard functions
  def build(quoted = {a, _, args}) when is_atom(a) and is_list(args) do
    predicate = Macro.to_string(quoted)

    quote do
      run = fn input ->
        input |> unquote(quoted)
      end

      %Spec{predicate: unquote(predicate), f: run, generator: unquote(a)}
    end
  end

  # Function without parens
  def build(quoted = {a, _, _}) when is_atom(a) do
    predicate = Macro.to_string(quoted) <> "()"

    quote do
      run = fn input ->
        input |> unquote(quoted)
      end

      %Spec{predicate: unquote(predicate), f: run, generator: unquote(a)}
    end
  end

  # Guard-safe functions in the Integer module.
  def build({{:., _, [{_, _, [:Integer]}, guard_name]}, _, _} = quoted)
    when guard_name in [:is_even, :is_odd] do
    predicate = Macro.to_string(quoted)

    quote do
      run = fn input ->
        input |> unquote(quoted)
      end

      %Spec{predicate: unquote(predicate), f: run, generator: unquote(guard_name)}
    end
  end

  # Remote call
  def build({{:., _, _}, _, _} = quoted) do
    predicate = Macro.to_string(quoted)

    quote do
      run = fn input ->
        input |> unquote(quoted)
      end

      %Spec{predicate: unquote(predicate), f: run, generator: :none}
    end
  end

  def build(quoted) do
    spec = Macro.to_string(quoted)

    raise ArgumentError, "Norm can't build a spec from: #{spec}"
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Norm.Generatable do
      def gen(%{generator: gen, predicate: pred}) do
        case build_generator(gen) do
          nil       -> {:error, pred}
          generator -> {:ok, generator}
        end
      end

      defp build_generator(gen) do
        case gen do
          :is_atom      -> StreamData.atom(:alphanumeric)
          :is_binary    -> StreamData.binary()
          :is_bitstring -> StreamData.bitstring()
          :is_boolean   -> StreamData.boolean()
          :is_float     -> StreamData.float()
          :is_integer   -> StreamData.integer()
          :is_list      -> StreamData.list_of(StreamData.term())
          :is_tuple     -> StreamData.list_of(StreamData.term()) |> StreamData.map(&List.to_tuple/1)
          :is_nil       -> StreamData.constant(nil)
          :is_number    -> StreamData.one_of([StreamData.integer(), StreamData.float()])
          :is_even      -> StreamData.integer() |> StreamData.map(&(&1 * 2))
          :is_odd      -> StreamData.integer() |> StreamData.map(&(&1 * 2 + 1))
          _             -> nil
        end
      end
    end
  end

  defimpl Norm.Conformer.Conformable do
    def conform(%{f: f, predicate: pred}, input, path) do
      case f.(input) do
        true ->
          {:ok, input}

        false ->
          {:error, [Norm.Conformer.error(path, input, pred)]}

        _ ->
          raise ArgumentError, "Predicates must return a boolean value"
      end
    end
  end

  @doc false
  def __inspect__(spec) do
    spec.predicate
  end

  defimpl Inspect do
    def inspect(spec, _) do
      Inspect.Algebra.concat(["#Norm.Spec<", spec.predicate, ">"])
    end
  end
end
