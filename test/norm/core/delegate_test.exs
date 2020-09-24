defmodule Norm.Core.DelegateTest do
  use Norm.Case, async: true

  defmodule Foo do
    def spec() do
      schema(%{"level" => spec(is_integer()), "foo" => delegate(&Foo.spec/0)})
    end
  end

  describe "delegate/1" do
    test "can write recursive specs with 'delegate'" do
      assert {:ok, _} = conform(%{}, Foo.spec())
      assert {:ok, _} = conform(%{"level" => 3}, Foo.spec())

      assert {:ok, _} = conform(%{"level" => 3, "foo" => %{"level" => 4}}, Foo.spec())

      assert {:ok, _} =
               conform(
                 %{"level" => 3, "foo" => %{"level" => 4, "foo" => %{"level" => 5}}},
                 Foo.spec()
               )

      assert {:error, [%{path: ["foo", "foo", "level"], spec: "is_integer()"}]} =
               conform(
                 %{"level" => 3, "foo" => %{"level" => 4, "foo" => %{"level" => "5"}}},
                 Foo.spec()
               )
    end
  end
end
