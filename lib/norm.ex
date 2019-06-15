defmodule Norm do
  @moduledoc """
  Norm provides a set of functions for specifying data.
  """

  alias Norm.Conformer
  alias Norm.Generatable
  alias Norm.Spec
  alias Norm.Schema

  defmodule MismatchError do
    defexception [:message]

    def exception(errors) do
      msg =
        errors
        |> Enum.join("\n")

      %__MODULE__{message: msg}
    end
  end

  defmodule GeneratorError do
    defexception [:message]

    def exception(predicate) do
      msg = "Unable to create a generator for: #{predicate}"
      %__MODULE__{message: msg}
    end
  end

  @doc ~S"""
  Verifies that the payload conforms to the specification
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

  @doc ~S"""
  Creates a re-usable schema

  iex> conform!(%{name: "Chris"}, schema(%{name: spec(is_binary())}))
  %{name: "Chris"}
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

  # @doc ~S"""
  # Choices between alternative predicates or patterns. The patterns must be tagged with an atom.
  # When conforming data to this specification the data is returned as a tuple with the tag.

  # iex> conform!(123, alt(num: integer?(), str: string?()))
  # {:num, 123}
  # iex> conform!("foo", alt(num: integer?(), str: string?()))
  # {:str, "foo"}
  # iex> conform(true, alt(num: integer?(), str: string?()))
  # {:error, ["in: :num val: true fails: integer?()", "in: :str val: true fails: string?()"]}
  # """
  # def alt(opts) do
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
  # end
end

