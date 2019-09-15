defmodule NormTest do
  use ExUnit.Case, async: true
  doctest Norm, import: true
  import Norm
  import ExUnitProperties, except: [gen: 1]

  describe "conform" do
    test "accepts specs" do
      assert {:ok, 123} = conform(123, spec(is_integer()))
    end

    test "can match atoms" do
      assert :ok == conform!(:ok, :ok)
      assert {:error, errors} = conform("foo", :ok)
      assert errors == ["val: \"foo\" fails: is not an atom."]
      assert {:error, errors} = conform(:mismatch, :ok)
      assert errors == ["val: :mismatch fails: == :ok"]
    end

    test "can match patterns of tuples" do
      ok = {:ok, spec(is_integer())}
      error = {:error, spec(is_binary())}
      three = {spec(is_integer()), spec(is_integer()), spec(is_integer())}

      assert {:ok, 123} == conform!({:ok, 123}, ok)

      assert {:error, "something's wrong"} == conform!({:error, "something's wrong"}, error)

      assert {1, 2, 3} == conform!({1, 2, 3}, three)
      assert {:error, errors} = conform({1, :bar, "foo"}, three)

      assert errors == [
               "val: :bar in: 1 fails: is_integer()",
               "val: \"foo\" in: 2 fails: is_integer()"
             ]

      assert {:error, errors} = conform({:ok, "foo"}, ok)
      assert errors == ["val: \"foo\" in: 1 fails: is_integer()"]

      assert {:error, errors} = conform({:ok, "foo", 123}, ok)
      assert errors == ["val: {:ok, \"foo\", 123} fails: incorrect tuple size"]

      assert {:error, errors} = conform({:ok, 123, "foo"}, ok)
      assert errors == ["val: {:ok, 123, \"foo\"} fails: incorrect tuple size"]
    end

    test "tuples can be composed with schema's and selections" do
      user = schema(%{name: spec(is_binary()), age: spec(is_integer())})
      ok = {:ok, selection(user, [:name])}

      assert {:ok, %{name: "chris"}} == conform!({:ok, %{name: "chris", age: 31}}, ok)
      assert {:error, errors} = conform({:ok, %{age: 31}}, ok)
      assert errors == ["val: %{age: 31} in: 1/:name fails: :required"]
    end

    @tag :skip
    test "can spec keyword lists" do
      flunk("Not Implemented")
    end
  end

  describe "gen" do
    property "works with atoms" do
      check all(foo <- gen(:foo)) do
        assert is_atom(foo)
        assert foo == :foo
      end

      check all(a <- gen(spec(is_atom()))) do
        assert is_atom(a)
      end
    end

    property "works with tuples" do
      ok = {:ok, schema(%{name: spec(is_binary())})}

      check all(tuple <- gen(ok)) do
        assert {:ok, user} = tuple
        assert Map.keys(user) == [:name]
        assert is_binary(user.name)
      end

      assert_raise Norm.GeneratorError, fn ->
        gen({spec(&(&1 > 0)), spec(is_binary())})
      end

      ints = {spec(is_binary()), spec(is_integer()), spec(is_integer())}

      check all(is <- gen(ints)) do
        assert {a, b, c} = is
        assert is_binary(a)
        assert is_integer(b)
        assert is_integer(c)
      end
    end
  end

  describe "with_gen" do
    test "overrides the default generator" do
      spec = with_gen(spec(is_integer()), gen(spec(is_binary())))
      for str <- Enum.take(gen(spec), 5), do: assert(is_binary(str))

      spec = with_gen(schema(%{foo: spec(is_integer())}), StreamData.constant("foo"))
      for str <- Enum.take(gen(spec), 5), do: assert(str == "foo")
    end
  end

  describe "schema/1" do
    test "creates a re-usable schema" do
      s = schema(%{name: spec(is_binary())})
      assert %{name: "Chris"} == conform!(%{name: "Chris"}, s)
      assert {:error, _errors} = conform(%{foo: "bar"}, s)
      assert {:error, _errors} = conform(%{name: 123}, s)

      user = schema(%{user: schema(%{name: spec(is_binary())})})
      assert %{user: %{name: "Chris"}} == conform!(%{user: %{name: "Chris"}}, user)
    end
  end

  describe "selection/1" do
    test "returns an error if passed a non-schema" do
      assert_raise FunctionClauseError, fn ->
        selection(spec(is_binary()), [])
      end
    end
  end

  describe "alt/1" do
    test "returns errors" do
      spec = alt(a: schema(%{name: spec(is_binary())}), b: spec(is_binary()))

      assert {:a, %{name: "alice"}} == conform!(%{name: "alice"}, spec)
      assert {:b, "foo"} == conform!("foo", spec)
      assert {:error, errors} = conform(%{name: :alice}, spec)

      assert errors == [
               "val: :alice in: :a/:name fails: is_binary()",
               "val: %{name: :alice} in: :b fails: is_binary()"
             ]
    end

    test "can generate data" do
      spec = alt(a: spec(is_binary()), b: spec(is_integer()))

      vals =
        spec
        |> gen()
        |> Enum.take(5)

      assert Enum.count(vals) == 5

      for val <- vals do
        assert is_binary(val) || is_integer(val)
      end
    end
  end

  describe "map_of" do
    test "can spec generic maps" do
      spec = map_of(spec(is_integer()), spec(is_atom()))
      assert %{1 => :foo, 2 => :bar} == conform!(%{1 => :foo, 2 => :bar}, spec)
    end

    property "can be generated" do
      check all m <- gen(map_of(spec(is_integer()), spec(is_atom()))) do
        assert is_map(m)
        for k <- Map.keys(m), do: assert is_integer(k)
        for v <- Map.values(m), do: assert is_atom(v)
      end
    end
  end

  describe "coll_of/2" do
    test "can spec collections" do
      spec = coll_of(spec(is_atom()))
      assert [:foo, :bar, :baz] == conform!([:foo, :bar, :baz], spec)
      assert {:error, errors} = conform([:foo, 1, "test"], spec)
      assert errors == [
        "val: 1 in: 1 fails: is_atom()",
        "val: \"test\" in: 2 fails: is_atom()"
      ]
    end

    test "conforming returns the conformed values" do
      spec = coll_of(schema(%{name: spec(is_binary())}))
      input = [
        %{name: "chris", age: 31, email: "c@keathley.io"},
        %{name: "andra", age: 30}
      ]

      assert [%{name: "chris"}, %{name: "andra"}] == conform!(input, spec)

      input = [
        %{age: 31, email: "c@keathley.io"},
        %{name: :andra, age: 30},
      ]
      assert {:error, errors} = conform(input, spec)
      assert errors == [
        "val: %{age: 31, email: \"c@keathley.io\"} in: 0/:name fails: :required",
        "val: :andra in: 1/:name fails: is_binary()"
      ]
    end

    test "can enforce distinct elements" do
      spec = coll_of(spec(is_integer()), distinct: true)

      assert {:error, errors} = conform([1,1,1], spec)
      assert errors == ["val: [1, 1, 1] fails: distinct?"]
    end

    test "can enforce min and max counts" do
      spec = coll_of(spec(is_integer()), min_count: 2, max_count: 3)
      assert [1, 1] == conform!([1, 1], spec)
      assert [1, 1, 1] == conform!([1, 1, 1], spec)
      assert {:error, ["val: [1] fails: min_count: 2"]} == conform([1], spec)
      assert {:error, ["val: [1, 1, 1, 1] fails: max_count: 3"]} == conform([1, 1, 1, 1], spec)

      spec = coll_of(spec(is_integer()), min_count: 3, max_count: 3)
      assert [1, 1, 1] == conform!([1, 1, 1], spec)
    end

    test "min count must be less than or equal to max count" do
      assert_raise ArgumentError, fn ->
        coll_of(spec(is_integer()), min_count: 3, max_count: 2)
      end
    end

    test "can be used to spec keyword lists" do
      opts = one_of([
        {:name, spec(is_atom())},
        {:timeout, spec(is_integer())}
      ])
      spec = coll_of(opts)
      list = [name: :storage, timeout: 3_000]

      assert list == conform!(list, spec)
      assert {:error, _errors} = conform([{:foo, :bar} | list], spec)

      assert list == conform!(list, coll_of(opts, [min_count: 2, distinct: true]))
      assert {:error, errors} = conform([], coll_of(opts, [min_count: 2, distinct: true]))
    end

    property "can be generated" do
      check all is <- gen(coll_of(spec(is_integer()))) do
        for i <- is, do: assert is_integer(i)
      end

      check all is <- gen(coll_of(spec(is_integer()), min_count: 3, max_count: 6)) do
        length = Enum.count(is)
        assert 3 <= length and length <= 6
      end

      check all is <- gen(coll_of(spec(is_integer()), distinct: true)) do
        assert Enum.uniq(is) == is
      end
    end
  end
end
