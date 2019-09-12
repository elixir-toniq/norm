defmodule Norm.Spec do
  @moduledoc false
  # Provides a struct to encapsulate specs

  alias __MODULE__

  alias Norm.Spec.{
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
      @supported_primitives [
        :is_atom,
        :is_binary,
        :is_bitstring,
        :is_boolean,
        :is_float,
        :is_integer
      ]

      def gen(%{generator: gen, predicate: pred}) do
        predicate =
          Enum.find(@supported_primitives, {:error, pred}, fn predicate ->
            gen == predicate
          end)

        generator_from_predicate(predicate)
      end

      defp generator_from_predicate({:error, predicate}), do: {:error, predicate}

      defp generator_from_predicate(:is_atom),
        do: {:ok, apply(StreamData, :atom, [:alphanumeric])}

      defp generator_from_predicate(predicate) do
        data_type =
          predicate
          |> Atom.to_string()
          |> String.slice(3..-1)
          |> String.to_atom()

        {:ok, apply(StreamData, data_type, [])}
      end
    end
  end

  defimpl Norm.Conformer.Conformable do
    def conform(%{f: f, predicate: pred}, input, path) do
      case f.(input) do
        true ->
          {:ok, input}

        false ->
          {:error, [error(path, input, pred)]}

        _ ->
          raise ArgumentError, "Predicates must return a boolean value"
      end
    end

    def error(path, input, msg) do
      %{path: path, input: input, msg: msg, at: nil}
    end
  end
end
