defmodule Norm.Spec do
  @moduledoc false
  # Provides a struct to encapsulate specs

  alias __MODULE__
  alias Norm.Spec.{
    And,
    Or,
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
      %And{left: unquote(l), right: unquote(r)}
    end
  end

  # Anonymous functions
  def build(quoted={f, _, _args}) when f in [:&, :fn] do
    predicate = Macro.to_string(quoted)

    quote do
      run = fn input ->
        input |> unquote(quoted).()
      end

      %Spec{generator: nil, predicate: unquote(predicate), f: run}
    end
  end

  # Standard functions
  def build(quoted={a, _, args}) when is_atom(a) and is_list(args) do
    predicate = Macro.to_string(quoted)

    quote do
      run = fn input ->
        input |> unquote(quoted)
      end

      %Spec{predicate: unquote(predicate), f: run, generator: unquote(a)}
    end
  end

  def build(quoted) do
    IO.inspect(quoted, label: "Missed one")
    expanded = Macro.expand(quoted, __ENV__)
    IO.inspect(expanded, label: "Expanded")
    # raise ArgumentError, "Norm has screwed up"
    quoted
  end

  defimpl Norm.Generatable do
    def gen(%{generator: gen, predicate: pred}) do
      case gen do
        :is_integer ->
          {:ok, StreamData.integer()}

        :is_binary ->
          {:ok, StreamData.binary()}

        _ ->
          {:error, pred}
      end
    end
  end

  # def build(int) when is_integer(int) do
  #   quote do
  #     unquote(int)
  #   end
  # end

  # def build({a, b}) do
  #   IO.inspect([a, b], label: "Two Tuple")
  #   l = build(a)
  #   r = build(b)

  #   quote do
  #     %Tuple{args: [unquote(l), unquote(r)]}
  #   end
  # end

  # def build({:{}, _, args}) do
  #   args = Enum.map(args, &build/1)

  #   quote do
  #     %Tuple{args: unquote(args)}
  #   end
  # end

  # @doc ~S"""
  # """
  # def lit(val) do
  #   fn path, input ->
  #     if input == val do
  #       {:ok, input}
  #     else
  #       {:error, [error(path, input, format_val(val))]}
  #     end
  #   end
  # end
  # def string? do
  #   fn path, input ->
  #     if is_binary(input) do
  #       {:ok, input}
  #     else
  #       {:error, [error(path, input, "string?()")]}
  #     end
  #   end
  # end

  # @doc ~S"""
  # Ands together two specs.

  # iex> conform(:atom, sand(string?(), lit("foo")))
  # {:error, ["val: :atom fails: string?()", "val: :atom fails: \"foo\""]}
  # iex> conform!("foo", sand(string?(), lit("foo")))
  # "foo"
  # """
  # def sand(l, r) do
  #   fn path, input ->
  #     errors =
  #       [l, r]
  #       |> Enum.map(fn spec -> spec.(path, input) end)
  #       |> Enum.filter(fn {result, _} -> result == :error end)
  #       |> Enum.flat_map(fn {_, msg} -> msg end)

  #     if Enum.any?(errors) do
  #       {:error, errors}
  #     else
  #       {:ok, input}
  #     end
  #   end
  # end

  # @doc ~S"""
  # Ors two specs together

  # iex> conform!("foo", sor(string?(), integer?()))
  # "foo"
  # iex> conform!(1, sor(string?(), integer?()))
  # 1
  # iex> conform(:atom, sor(string?(), integer?()))
  # {:error, ["val: :atom fails: string?()", "val: :atom fails: integer?()"]}
  # """
  # def sor(l, r) do
  #   fn path, input ->
  #     case l.(path, input) do
  #       {:ok, input} ->
  #         {:ok, input}

  #       {:error, l_errors} ->
  #         # credo:disable-for-next-line /\.Nesting/
  #         case r.(path, input) do
  #           {:ok, input} ->
  #             {:ok, input}

  #           {:error, r_errors} ->
  #             {:error, l_errors ++ r_errors}
  #         end
  #     end
  #   end
  # end

  # @doc ~S"""
  # Creates a spec for keyable things such as maps

  # iex> conform!(%{foo: "foo"}, keys(req: [foo: string?()]))
  # %{foo: "foo"}
  # iex> conform!(%{foo: "foo", bar: "bar"}, keys(req: [foo: string?()]))
  # %{foo: "foo"}
  # iex> conform!(%{"foo" => "foo", bar: "bar"}, keys(req: [{"foo", string?()}]))
  # %{"foo" => "foo"}
  # iex> conform!(%{foo: "foo"}, keys(req: [foo: string?()], opt: [bar: string?()]))
  # %{foo: "foo"}
  # iex> conform!(%{foo: "foo", bar: "bar"}, keys(req: [foo: string?()], opt: [bar: string?()]))
  # %{foo: "foo", bar: "bar"}
  # iex> conform(%{}, keys(req: [foo: string?()]))
  # {:error, ["in: :foo val: %{} fails: :required"]}
  # iex> conform(%{foo: 123, bar: "bar"}, keys(req: [foo: string?()]))
  # {:error, ["in: :foo val: 123 fails: string?()"]}
  # iex> conform(%{foo: 123, bar: 321}, keys(req: [foo: string?()], opt: [bar: string?()]))
  # {:error, ["in: :foo val: 123 fails: string?()", "in: :bar val: 321 fails: string?()"]}
  # iex> conform!(%{foo: "foo", bar: %{baz: "baz"}}, keys(req: [foo: string?(), bar: keys(req: [baz: lit("baz")])]))
  # %{foo: "foo", bar: %{baz: "baz"}}
  # iex> conform(%{foo: 123, bar: %{baz: 321}}, keys(req: [foo: string?()], opt: [bar: string?()]))
  # iex> conform(%{foo: 123, bar: %{baz: 321}}, keys(req: [foo: string?(), bar: keys(req: [baz: lit("baz")])]))
  # {:error, ["in: :foo val: 123 fails: string?()", "in: :bar/:baz val: 321 fails: \"baz\""]}
  # """
  # def keys(specs) do
  #   reqs = Keyword.get(specs, :req, [])
  #   opts = Keyword.get(specs, :opt, [])

  #   fn path, input ->
  #     req_keys = Enum.map(reqs, fn {key, _} -> key end)
  #     opt_keys = Enum.map(opts, fn {key, _} -> key end)

  #     req_errors =
  #       reqs
  #       |> Enum.map(fn {key, spec} ->
  #         # credo:disable-for-next-line /\.Nesting/
  #         if Map.has_key?(input, key) do
  #           {key, spec.(path ++ [key], input[key])}
  #         else
  #           {key, {:error, [error(path ++ [key], input, ":required")]}}
  #         end
  #       end)
  #       |> Enum.filter(fn {_, {result, _}} -> result == :error end)
  #       |> Enum.flat_map(fn {_, {_, errors}} -> errors end)

  #     opt_errors =
  #       opts
  #       |> Enum.map(fn {key, spec} ->
  #         # credo:disable-for-next-line /\.Nesting/
  #         if Map.has_key?(input, key) do
  #           {key, spec.(path ++ [key], input[key])}
  #         else
  #           {key, {:ok, nil}}
  #         end
  #       end)
  #       |> Enum.filter(fn {_, {result, _}} -> result == :error end)
  #       |> Enum.flat_map(fn {_, {_, errors}} -> errors end)

  #     errors = req_errors ++ opt_errors
  #     keys = req_keys ++ opt_keys

  #     if Enum.any?(errors) do
  #       {:error, errors}
  #     else
  #       {:ok, Map.take(input, keys)}
  #     end
  #   end
  # end

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
