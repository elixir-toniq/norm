defmodule NormTest do
  use ExUnit.Case
  doctest Norm
  use Norm

  describe ".conform/2" do
    test "returns a result" do
      {:ok, data} = Norm.conform(Norm.integer?(), 2)
      assert data == 2

      {:error, result} = Norm.conform(Norm.integer?, "foo")
      assert Norm.explain(result) == ~s|val: "foo" fails spec: integer?|
    end
  end

  test "can define schemas" do
    user_event = Norm.schema(
      reqs: [id: Norm.integer?(), first_name: Norm.string?()],
      opts: [age: Norm.integer?() and Norm.positive?()])

    input = %{
      id: 123,
      first_name: "Chris",
      age: 30
    }

    assert {:ok, data} = Norm.conform(user_event, input)
  end

  test "explains errors" do
    UserSchema = Norm.schema(
      reqs: [
        id: Norm.integer?(),
        first_name: Norm.string?(),
        last_name: Norm.string?(),
        age: Norm.integer?() and Norm.positive?(),
      ])

    input = %{
      "id" => "123",
      "first_name" => 123,
      "age" => -32
    }

    {:error, result} = Norm.conform(UserSchema, input)
    assert Norm.explain_data(result) == [
      "In :id, val: \"123\" fails spec: integer?",
      "In :first_name, val: 123 fails spec: string?",
      "In :last_name, val: {\"id\"=>\"123\", \"first_name\"=>123, \"age\"=>-32} fails spec: required",
      "In :age, val: -32 fails spec: positive?",
    ]
  end

  test "handles nested schemas" do
    Bio = schema(
      reqs: [
        id: integer?(),
        details: schema(reqs: [bio: string?()]),
      ])

    input = %{
      "id" => 123,
      "details" => %{
        "bio" => "This is my bio"
      }
    }

    {:ok, data} = Norm.conform(Bio, input)

    input = %{
      "id" => "123",
      "details" => %{
        "bio" => 123
      }
    }

    {:error, result} = Norm.conform(Bio, input)
    assert Norm.explain_data(result) == [
      "In :id, val: \"123\" fails spec: integer?",
      "In :details/:bio, val: 123 fails spec: string?"
    ]
  end

  test "can combine specs with and" do
    assert {:ok, 3} == Norm.conform(Norm.integer? and Norm.positive?, 3)
    assert {:error, result} = Norm.conform(Norm.integer? and Norm.positive?, -3)
    assert Norm.explain(result) == ~r/fails spec: positive\?/
  end

  test "can combine specs with or" do
    assert {:ok, 3} == Norm.conform(Norm.integer? or Norm.string?, 3)
    assert {:ok, "3"} == Norm.conform(Norm.integer? or Norm.string?, "3")

    assert {:error, result} = Norm.conform(Norm.integer? or Norm.string?, [])
    assert Norm.explain_data(result) == [
      ~s|fails spec: string?|,
      ~s|fails spec: integer|
    ]
  end

  test "can combine specs arbitratily" do
    spec = spec(Norm.string? or (Norm.integer? and Norm.positive?))
    assert {:ok, 42} == Norm.conform(spec, 42)

    assert {:error, result} = Norm.conform(spec, -42)
    assert Norm.explain_data(result) == [
      ~s|val: -42 fails spec: string?|,
      ~s|val: -42 fails spec: positive?|,
    ]

    schema = Norm.schema do
      req :details,(Norm.schema do
        req :id, spec
      end)
    end

    assert {:ok, %{details: %{id: 42}}} = Norm.conform(schema, %{details: %{id: 42}})
    assert {:error, result} = Norm.conform(schema, %{details: %{id: -42}})
    assert Norm.explain_data(result) == [
      ~s|In :details/:id, val: -42 fails spec: string?|,
      ~s|In :details/:id, val: -42 fails spec: positive?|,
    ]
  end

  test 'handles regex' do
    assert {:ok, "123"} == Norm.conform(Norm.re_matches?(~r/123/), "123")
    assert {:error, result} = Norm.conform(Norm.re_matches?(~r/123/), "321")
    assert Norm.explain(result) == ~r/fails spec: re_matches\?/
    assert {:error, result} = Norm.conform(Norm.re_matches?(~r/123/), 123)
    assert Norm.explain(result) == ~r/fails spec: re_matches\?/
  end

  test "allows optional fields" do
    event = Norm.schema(opts: [foo: lit("bar")])

    assert {:ok, %{"foo" => "bar"}} = Norm.conform(event, %{"foo" => "bar"})
    assert {:error, _} = Norm.conform(event, %{"foo" => "baz"})
    assert {:ok, %{"other" => "key"}} == Norm.conform(event, %{"other" => "key"})
  end
end
