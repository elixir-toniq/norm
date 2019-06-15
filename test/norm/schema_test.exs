defmodule Norm.SchemaTest do
  use ExUnit.Case, async: true
  import Norm

  defmodule User do
    import Norm

    defstruct ~w|name email age|a

    def s, do: schema(%__MODULE__{
      name: spec(is_binary()),
      email: spec(is_binary()),
      age: spec(is_integer())
    })

    def chris do
      %__MODULE__{name: "chris", email: "c@keathley.io", age: 31}
    end
  end

  defmodule OtherUser do
    defstruct ~w|name email age|a
  end

  test "creates a re-usable schema" do
    s = schema(%{name: spec(is_binary())})
    assert %{name: "Chris"} == conform!(%{name: "Chris"}, s)
    assert {:error, _errors} = conform(%{foo: "bar"}, s)
    assert {:error, _errors} = conform(%{name: 123}, s)

    user = schema(%{user: schema(%{name: spec(is_binary())})})
    assert %{user: %{name: "Chris"}} == conform!(%{user: %{name: "Chris"}}, user)
  end

  test "requires all of the keys specified in the schema" do
    s = schema(%{
      name: spec(is_binary()),
      age: spec(is_integer()),
    })

    assert %{name: "chris", age: 31} == conform!(%{name: "chris", age: 31}, s)
    assert {:error, errors} = conform(%{name: "chris"}, s)
    assert errors == ["in: :age val: %{name: \"chris\"} fails: :required"]

    user = schema(%{user: s})
    assert {:error, errors} = conform(%{user: %{age: 31}}, user)
    assert errors == ["in: :user/:name val: %{age: 31} fails: :required"]
  end

  describe "generation" do
    test "works with maps" do
      s = schema(%{
        name: spec(is_binary()),
        age: spec(is_integer())
      })

      maps =
        s
        |> gen()
        |> Enum.take(10)

      for map <- maps do
        assert is_map(map)
        assert match?(%{name: _, age: _}, map)
        assert is_binary(map.name)
        assert is_integer(map.age)
      end
    end

    test "returns errors if it contains unknown generators" do
      s = schema(%{
        age: spec(&(&1 > 0))
      })

      assert_raise Norm.GeneratorError, "Unable to create a generator for: &(&1 > 0)", fn ->
        gen(s)
      end
    end
  end

  @tag :skip
  test "schemas can be composed with other specs" do
    flunk "Not implemented"
  end

  describe "schema/1 with struct" do
    test "fails non-structs when the schema is a struct" do
      input = Map.from_struct(User.chris())

      assert {:error, errors} = conform(input, schema(%User{}))
      assert errors == ["val: %{age: 31, email: \"c@keathley.io\", name: \"chris\"} fails: Norm.SchemaTest.User"]
    end

    test "fails if the wrong struct is passed" do
      input = User.chris()

      assert {:error, errors} = conform(input, schema(%OtherUser{}))
      assert errors == ["val: %Norm.SchemaTest.User{age: 31, email: \"c@keathley.io\", name: \"chris\"} fails: Norm.SchemaTest.OtherUser"]
    end

    test "can create a schema from a struct" do
      s = schema(%User{})

      assert User.chris() == conform!(User.chris(), s)
    end

    test "can specify specs for keys" do
      input = User.chris()

      assert input == conform!(input, User.s())
      assert {:error, errors} = conform(%User{name: :foo, age: "31", email: 42}, User.s())
      assert errors == ["in: :age val: \"31\" fails: is_integer()",
                        "in: :email val: 42 fails: is_binary()",
                        "in: :name val: :foo fails: is_binary()"]
    end

    test "only checks the keys that have specs" do
      input = User.chris()
      spec = schema(%User{name: spec(is_binary())})

      assert input == conform!(input, spec)
      assert {:error, errors} = conform(%User{name: 23}, spec)
      assert errors == ["in: :name val: 23 fails: is_binary()"]
    end
  end
end
