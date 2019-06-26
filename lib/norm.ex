defmodule Norm do
  @moduledoc """
  Norm provides a set of functions for specifying data.
  """

  alias Norm.Conformer
  alias Norm.Generatable
  alias Norm.Generator
  alias Norm.Spec
  alias Norm.Spec.{
    Alt,
    Selection,
  }
  alias Norm.Schema
  alias Norm.MismatchError
  alias Norm.GeneratorError

  @doc ~S"""
  Verifies that the payload conforms to the specification

  ## Examples:

  iex> conform(42, spec(is_integer()))
  {:ok, 42}
  iex> conform(42, spec(fn x -> x == 42 end))
  {:ok, 42}
  iex> conform(42, spec(&(&1 >= 0)))
  {:ok, 42}
  iex> conform(42, spec(&(&1 >= 100)))
  {:error, ["val: 42 fails: &(&1 >= 100)"]}
  iex> conform("foo", spec(is_integer()))
  {:error, ["val: \"foo\" fails: is_integer()"]}
  """
  def conform(input, spec) do
    Conformer.conform(spec, input)
  end

  @doc ~S"""
  Verifies that the payload conforms to the specification or raises a Mismatch
  error
  """
  def conform!(input, spec) do
    case Conformer.conform(spec, input) do
      {:ok, input} -> input
      {:error, errors} -> raise MismatchError, errors
    end
  end

  @doc ~S"""
  Checks if the value conforms to the spec and returns a boolean.

  iex> valid?(42,  spec(is_integer()))
  true
  iex> valid?("foo",  spec(is_integer()))
  false
  """
  def valid?(input, spec) do
    case Conformer.conform(spec, input) do
      {:ok, _}    -> true
      {:error, _} -> false
    end
  end

  @doc ~S"""
  Creates a generator from a spec or predicate.

  iex> gen(spec(is_integer())) |> Enum.take(3) |> Enum.all?(&is_integer/1)
  true
  iex> gen(spec(is_binary())) |> Enum.take(3) |> Enum.all?(&is_binary/1)
  true
  iex> gen(spec(&(&1 > 0)))
  ** (Norm.GeneratorError) Unable to create a generator for: &(&1 > 0)
  """
  def gen(spec) do
    case Generatable.gen(spec) do
      {:ok, generator} -> generator
      {:error, error} -> raise GeneratorError, error
    end
  end

  @doc """
  Overwrites the default generator with a custom generator. The generator
  can be any valid StreamData generator. This means you can either use Norms
  built in `gen/1` function or you can drop into StreamData directly.

  ## Examples

      iex> Enum.take(gen(with_gen(spec(is_integer()), StreamData.constant("hello world"))), 3)
      ["hello world", "hello world", "hello world"]
  """
  def with_gen(spec, %StreamData{}=generator) do
    Generator.new(spec, generator)
  end

  @doc ~S"""
  Creates a new spec. Specs can be created from any existing predicates or
  anonymous functions. Specs must return a boolean value.

  Predicates can be arbitrarily composed using the `and` and `or` keywords.

  ## Examples:
  iex> conform!(21, spec(is_integer()))
  21
  iex> conform!(21, spec(is_integer() and &(&1 >= 21)))
  21
  iex> conform("21", spec(is_integer() and &(&1 >= 21)))
  {:error, ["val: \"21\" fails: is_integer()"]}
  iex> conform!(:foo, spec(is_atom() or is_binary()))
  :foo
  iex> conform!("foo", spec(is_atom() or is_binary()))
  "foo"
  iex> conform(21, spec(is_atom() or is_binary()))
  {:error, ["val: 21 fails: is_atom()", "val: 21 fails: is_binary()"]}
  """
  defmacro spec(predicate) do
    spec = Spec.build(predicate)

    quote do
      unquote(spec)
    end
  end

  @doc ~S"""
  Creates a re-usable schema.
  """
  def schema(input) do
    Schema.build(input)
  end

  @doc ~S"""
  Choices between alternative predicates or patterns. The patterns must be tagged with an atom.
  When conforming data to this specification the data is returned as a tuple with the tag.

  ## Examples

  iex> conform!("foo", alt(s: spec(is_binary()), a: spec(is_atom())))
  {:s, "foo"}
  iex> conform!(:foo, alt(s: spec(is_binary()), a: spec(is_atom())))
  {:a, :foo}
  iex> conform!(123, alt(num: spec(is_integer()), str: spec(is_binary())))
  {:num, 123}
  iex> conform!("foo", alt(num: spec(is_integer()), str: spec(is_binary())))
  {:str, "foo"}
  iex> conform(true, alt(num: spec(is_integer()), str: spec(is_binary())))
  {:error, ["in: :num val: true fails: is_integer()", "in: :str val: true fails: is_binary()"]}
  """
  def alt(specs) when is_list(specs) do
    %Alt{specs: specs}
  end

  @doc ~S"""
  Specifies a selection of keys from a schema. This allows callsites to
  define what keys must be available from the input.
  """
  def selection(%Schema{}=schema) do
    Selection.new(schema, :all)
  end

  def selection(%Schema{}=schema, path) do
    Selection.new(schema, path)
  end

  # @doc ~S"""
  # Concatenates a sequence of predicates or patterns together. These predicates
  # must be tagged with an atom. The conformed data is returned as a
  # keyword list.

  # iex> conform!([31, "Chris"], cat(age: integer?(), name: string?()))
  # [age: 31, name: "Chris"]
  # iex> conform([true, "Chris"], cat(age: integer?(), name: string?()))
  # {:error, ["in: [0] at: :age val: true fails: integer?()"]}
  # iex> conform([31, :chris], cat(age: integer?(), name: string?()))
  # {:error, ["in: [1] at: :name val: :chris fails: string?()"]}
  # iex> conform([31], cat(age: integer?(), name: string?()))
  # {:error, ["in: [1] at: :name val: nil fails: Insufficient input"]}
  # """
  # def cat(opts) do
  #   fn path, input ->
  #     results =
  #       opts
  #       |> Enum.with_index
  #       |> Enum.map(fn {{tag, spec}, i} ->
  #         val = Enum.at(input, i)
  #         if val do
  #           {tag, spec.(path ++ [{:index, i}], val)}
  #         else
  #           {tag, {:error, [error(path ++ [{:index, i}], nil, "Insufficient input")]}}
  #         end
  #       end)

  #     errors =
  #       results
  #       |> Enum.filter(fn {_, {result, _}} -> result == :error end)
  #       |> Enum.map(fn {tag, {_, errors}} -> {tag, errors} end)
  #       |> Enum.flat_map(fn {tag, errors} -> Enum.map(errors, &(%{&1 | at: tag})) end)

  #     if Enum.any?(errors) do
  #       {:error, errors}
  #     else
  #       {:ok, Enum.map(results, fn {tag, {_, data}} -> {tag, data} end)}
  #     end
  #   end
  # end
end

