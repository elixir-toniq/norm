defmodule Norm.Core.AllOfTest do
  use Norm.Case, async: true

  describe "conforming" do
    test "returns the conformed value" do
      foo = all_of([spec(is_atom), :foo])

      assert :foo == conform!(:foo, foo)
      assert {:error, errors} = conform(123, foo)
      assert errors == [
        %{spec: "is_atom()", input: 123, path: []},
        %{spec: "is not an atom.", input: 123, path: []}
      ]

      assert {:error, errors} = conform(:bar, foo)
      assert errors == [
        %{spec: "== :foo", input: :bar, path: []}
      ]

      flunk "These are probably wrong"
    end
  end
end
