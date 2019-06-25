defmodule Norm.SelectionTest do
  use ExUnit.Case, async: true
  import Norm

  def user_schema, do: schema(%{
      name: spec(is_binary()),
      age: spec(is_integer() and &(&1 > 0)),
      email: spec(is_binary() and &(&1 =~ ~r/@/))
    })

  @input %{
    name: "chris",
    age: 31,
    email: "c@keathley.io"
  }

  describe "selection/2" do
    test "can define selections of schemas" do
      assert %{age: 31} == conform!(@input, selection(user_schema(), [:age]))
      assert %{age: 31, name: "chris"} == conform!(@input, selection(user_schema(), [:age, :name]))
      assert {:error, errors} = conform(%{age: -100}, selection(user_schema(), [:age]))
      assert errors == ["in: :age val: -100 fails: &(&1 > 0)"]
    end

    test "works with nested schemas" do
      schema = schema(%{user: user_schema()})
      selection = selection(schema, [user: [:age]])

      assert %{user: %{age: 31}} == conform!(%{user: %{age: 31}}, selection)
      assert {:error, errors} = conform(%{user: %{age: -100}}, selection)
      assert errors == ["in: :user/:age val: -100 fails: &(&1 > 0)"]
      assert {:error, errors} = conform(%{user: %{name: "chris"}}, selection)
      assert errors == ["in: :user/:age val: %{name: \"chris\"} fails: :required"]
      assert {:error, errors} = conform(%{fauxuser: %{age: 31}}, selection)
      assert errors == ["in: :user val: %{fauxuser: %{age: 31}} fails: :required"]
    end

    test "errors if there are keys that aren't specified in a schema" do
      assert_raise Norm.SpecError, fn ->
        selection(schema(%{age: spec(is_integer())}), [:name])
      end
      assert_raise Norm.SpecError, fn ->
        selection(schema(%{user: schema(%{age: spec(is_integer())})}), [user: [:name]])
      end
      assert_raise Norm.SpecError, fn ->
        selection(schema(%{user: schema(%{age: spec(is_integer())})}), [foo: [:name]])
      end
    end

    test "allows schemas to grow" do
      schema = schema(%{user: schema(%{name: spec(is_binary())})})
      select = selection(schema, [user: [:name]])

      assert %{user: %{name: "chris"}} == conform!(%{user: %{name: "chris", age: 31}, foo: :foo}, select)
    end
  end

  describe "generation" do
    test "can generate values" do
      s = schema(%{
        name: spec(is_binary()),
        age: spec(is_integer())
      })
      select = selection(s, [:name, :age])

      maps =
        select
        |> gen()
        |> Enum.take(10)

      for map <- maps do
        assert is_map(map)
        assert match?(%{name: _, age: _}, map)
        assert is_binary(map.name)
        assert is_integer(map.age)
      end
    end

    test "can generate subsets" do
      s = schema(%{
        name: spec(is_binary()),
        age: spec(is_integer())
      })
      select = selection(s, [:age])

      maps =
        select
        |> gen()
        |> Enum.take(10)

      for map <- maps do
        assert is_map(map)
        assert match?(%{age: _}, map)
        assert is_integer(map.age)
      end
    end

    test "can generate inner schemas" do
      s = schema(%{
        user: schema(%{
          name: spec(is_binary()),
          age: spec(is_integer())
        })
      })
      select = selection(s, [user: [:age]])

      maps =
        select
        |> gen()
        |> Enum.take(10)

      for map <- maps do
        assert is_map(map)
        assert match?(%{user: %{age: _}}, map)
        assert is_integer(map.user.age)
      end
    end
  end
end

