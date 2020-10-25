defmodule Norm do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  alias Norm.Conformer
  alias Norm.Generatable
  alias Norm.Generator
  alias Norm.MismatchError
  alias Norm.GeneratorError
  alias Norm.Core.{
    Alt,
    AnyOf,
    Collection,
    Schema,
    Selection,
    Spec,
    Delegate
  }

  @doc false
  defmacro __using__(_) do
    quote do
      import Norm
      use Norm.Contract
    end
  end

  @doc ~S"""
  Verifies that the payload conforms to the specification. A "success tuple"
  is returned that contains either the conformed value or the error explanation.

  ## Examples:

      iex> conform(42, spec(is_integer()))
      {:ok, 42}
      iex> conform(42, spec(fn x -> x == 42 end))
      {:ok, 42}
      iex> conform(42, spec(&(&1 >= 0)))
      {:ok, 42}
      iex> conform(42, spec(&(&1 >= 100)))
      {:error, [%{spec: "&(&1 >= 100)", input: 42, path: []}]}
      iex> conform("foo", spec(is_integer()))
      {:error, [%{spec: "is_integer()", input: "foo", path: []}]}
  """
  def conform(input, spec) do
    Conformer.conform(spec, input)
  end

  @doc ~s"""
  Returns the conformed value or raises a mismatch error.

  ## Examples

      iex> conform!(42, spec(is_integer()))
      42
      iex> conform!(42, spec(is_binary()))
      ** (Norm.MismatchError) Could not conform input:
      val: 42 fails: is_binary()
  """
  def conform!(input, spec) do
    case Conformer.conform(spec, input) do
      {:ok, input} -> input
      {:error, errors} -> raise MismatchError, errors
    end
  end

  @doc ~S"""
  Checks if the value conforms to the spec and returns a boolean.

  ## Examples

      iex> valid?(42,  spec(is_integer()))
      true
      iex> valid?("foo",  spec(is_integer()))
      false
  """
  def valid?(input, spec) do
    case Conformer.conform(spec, input) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc ~S"""
  Creates a generator from a spec, schema, or selection.

  ## Examples

      iex> gen(spec(is_integer())) |> Enum.take(3) |> Enum.all?(&is_integer/1)
      true
      iex> gen(spec(is_binary())) |> Enum.take(3) |> Enum.all?(&is_binary/1)
      true
      iex> gen(spec(&(&1 > 0)))
      ** (Norm.GeneratorError) Unable to create a generator for: &(&1 > 0)
  """
  def gen(spec) do
    if Code.ensure_loaded?(StreamData) do
      case Generatable.gen(spec) do
        {:ok, generator} -> generator
        {:error, error} -> raise GeneratorError, error
      end
    else
      raise Norm.GeneratorLibraryError
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
  if Code.ensure_loaded?(StreamData) do
    def with_gen(spec, %StreamData{} = generator) do
      Generator.new(spec, generator)
    end
  else
    def with_gen(spec, _) do
      Generator.new(spec, :null)
    end
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
      {:error, [%{spec: "is_integer()", input: "21", path: []}]}
      iex> conform!(:foo, spec(is_atom() or is_binary()))
      :foo
      iex> conform!("foo", spec(is_atom() or is_binary()))
      "foo"
      iex> conform(21, spec(is_atom() or is_binary()))
      {:error, [%{spec: "is_atom()", input: 21, path: []}, %{spec: "is_binary()", input: 21, path: []}]}
  """
  defmacro spec(predicate) do
    Spec.build(predicate)
  end

  @doc ~S"""
  Allows encapsulation of a spec in another function. This enables late-binding of
  specs which enables definition of recursive specs.

  ## Examples:
      iex> conform!(%{"value" => 1, "left" => %{"value" => 2, "right" => %{"value" => 4}}}, Norm.Core.DelegateTest.TreeTest.spec())
      %{"value" => 1, "left" => %{"value" => 2, "right" => %{"value" => 4}}}
      iex> conform(%{"value" => 1, "left" => %{"value" => 2, "right" => %{"value" => 4, "right" => %{"value" => "12"}}}}, Norm.Core.DelegateTest.TreeTest.spec())
      {:error, [%{input: "12", path: ["left", "right", "right", "value"], spec: "is_integer()"}]}
  """
  def delegate(predicate) do
    Delegate.build(predicate)
  end

  @doc ~S"""
  Creates a re-usable schema. Schema's are open which means that all keys are
  optional and any non-specified keys are passed through without being conformed.
  If you need to mark keys as required instead of optional you can use `selection`.

  ## Examples

      iex> valid?(%{}, schema(%{name: spec(is_binary())}))
      true
      iex> valid?(%{name: "Chris"}, schema(%{name: spec(is_binary())}))
      true
      iex> valid?(%{name: "Chris", age: 31}, schema(%{name: spec(is_binary())}))
      true
      iex> valid?(%{age: 31}, schema(%{name: spec(is_binary())}))
      true
      iex> valid?(%{name: 123}, schema(%{name: spec(is_binary())}))
      false
      iex> conform!(%{}, schema(%{name: spec(is_binary())}))
      %{}
      iex> conform!(%{age: 31, name: "chris"}, schema(%{name: spec(is_binary())}))
      %{age: 31, name: "chris"}
      iex> conform!(%{age: 31}, schema(%{name: spec(is_binary())}))
      %{age: 31}
      iex> conform!(%{user: %{name: "chris"}}, schema(%{user: schema(%{name: spec(is_binary())})}))
      %{user: %{name: "chris"}}
  """
  def schema(input) when is_map(input) do
    Schema.build(input)
  end

  @doc ~S"""
  Selections can be used to mark keys on a schema as required. Any unspecified keys
  in the selection are still considered optional. Selections, like schemas,
  are open and allow unspecied keys to be passed through. If no selectors are
  provided then `selection` defaults to `:all` and recursively marks all keys in
  all nested schema's. If the schema includes internal selections these selections
  will not be overwritten.

  ## Examples

      iex> valid?(%{name: "chris"}, selection(schema(%{name: spec(is_binary())}), [:name]))
      true
      iex> valid?(%{}, selection(schema(%{name: spec(is_binary())}), [:name]))
      false
      iex> valid?(%{user: %{name: "chris"}}, selection(schema(%{user: schema(%{name: spec(is_binary())})}), [user: [:name]]))
      true
      iex> conform!(%{name: "chris"}, selection(schema(%{name: spec(is_binary())}), [:name]))
      %{name: "chris"}
      iex> conform!(%{name: "chris", age: 31}, selection(schema(%{name: spec(is_binary())}), [:name]))
      %{name: "chris", age: 31}

  ## Require all keys
      iex> valid?(%{user: %{name: "chris"}}, selection(schema(%{user: schema(%{name: spec(is_binary())})})))
      true
  """
  def selection(%Schema{} = schema, path \\ :all) do
    Selection.new(schema, path)
  end

  @doc ~S"""
  Chooses between alternative predicates or patterns. The patterns must be tagged with an atom.
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
      {:error, [%{spec: "is_integer()", input: true, path: [:num]}, %{spec: "is_binary()", input: true, path: [:str]}]}
  """
  def alt(specs) when is_list(specs) do
    %Alt{specs: specs}
  end

  @doc """
  Chooses between a list of options. Unlike `alt/1` the options don't need to
  be tagged. Specs are always tested in order and will short circuit if the
  data passes a validation.

  ## Examples
      iex> conform!("chris", one_of([spec(is_binary()), :alice]))
      "chris"
      iex> conform!(:alice, one_of([spec(is_binary()), :alice]))
      :alice
  """
  def one_of(specs) when is_list(specs) do
    AnyOf.new(specs)
  end

  @doc ~S"""
  Specifies a generic collection. Collections can be any enumerable type.

  `coll_of` takes multiple arguments:

  * `:kind` - predicate function the kind of collection being conformed
  * `:distinct` - boolean value for specifying if the collection should have distinct elements
  * `:min_count` - Minimum element count
  * `:max_count` - Maximum element count
  * `:into` - The output collection the input will be conformed into. If not specified then the input type will be used.

  ## Examples

      iex> conform!([:a, :b, :c], coll_of(spec(is_atom())))
      [:a, :b, :c]
      iex> conform!([:a, :b, :c], coll_of(spec(is_atom), into: MapSet.new()))
      MapSet.new([:a, :b, :c])
      iex> conform!(MapSet.new([:a, :b, :c]), coll_of(spec(is_atom)))
      MapSet.new([:a, :b, :c])
      iex> conform!(%{a: 1, b: 2, c: 3}, coll_of({spec(is_atom), spec(is_integer)}))
      %{a: 1, b: 2, c: 3}
      iex> conform!([1, 2], coll_of(spec(is_integer), min_count: 1))
      [1, 2]
  """
  @default_opts [
    kind: nil,
    distinct: false,
    min_count: 0,
    max_count: :infinity,
    into: nil,
  ]

  def coll_of(spec, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    if opts[:min_count] > opts[:max_count] do
      raise ArgumentError, "min_count cannot be larger than max_count"
    end

    Collection.new(spec, opts)
  end

  @doc ~S"""
  Specifies a map with a type of key and a type of value.

  ## Examples

      iex> conform!(%{a: 1, b: 2, c: 3}, map_of(spec(is_atom()), spec(is_integer())))
      %{a: 1, b: 2, c: 3}
  """
  def map_of(kpred, vpred, opts \\ []) do
    opts = Keyword.merge(opts, [into: %{}, kind: &is_map/1])
    coll_of({kpred, vpred}, opts)
  end

  # @doc ~S"""
  # Concatenates a sequence of predicates or patterns together. These predicates
  # must be tagged with an atom. The conformed data is returned as a
  # keyword list.

  # iex> conform!([31, "Chris"], cat(age: integer?(), name: string?()))
  # [age: 31, name: "Chris"]
  # iex> conform([true, "Chris"], cat(age: integer?(), name: string?()))
  # {:error, ["in: [0] at: :age val: true spec: integer?()"]}
  # iex> conform([31, :chris], cat(age: integer?(), name: string?()))
  # {:error, ["in: [1] at: :name val: :chris spec: string?()"]}
  # iex> conform([31], cat(age: integer?(), name: string?()))
  # {:error, ["in: [1] at: :name val: nil spec: Insufficient input"]}
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
