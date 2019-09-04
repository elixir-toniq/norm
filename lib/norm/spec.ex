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
      def gen(%{generator: gen, predicate: pred}) do
        case gen do
          :is_integer ->
            {:ok, StreamData.integer()}

          :is_binary ->
            {:ok, StreamData.binary()}

          :is_atom ->
            {:ok, StreamData.atom(:alphanumeric)}

          _ ->
            {:error, pred}
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
