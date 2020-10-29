defmodule Norm.Core.DelegateTest do
  use Norm.Case, async: true

  defmodule TreeTest do
    def spec do
      schema(%{
        "value" => spec(is_integer()),
        "left" => delegate(&TreeTest.spec/0),
        "right" => delegate(&TreeTest.spec/0)
      })
    end
  end

  describe "delegate/1" do
    test "can write recursive specs with 'delegate'" do
      assert {:ok, _} = conform(%{}, TreeTest.spec())

      assert {:ok, _} =
               conform(
                 %{"value" => 4, "left" => %{"value" => 2}, "right" => %{"value" => 12}},
                 TreeTest.spec()
               )

      assert {:error, [%{input: "12", path: ["left", "left", "value"], spec: "is_integer()"}]} =
               conform(
                 %{
                   "value" => 4,
                   "left" => %{"value" => 2, "left" => %{"value" => "12"}},
                   "right" => %{"value" => 12}
                 },
                 TreeTest.spec()
               )
    end
  end
end
