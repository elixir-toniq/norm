defmodule Norm.Core.CollectionTest do
  use Norm.Case, async: true

  test "inspect" do
    spec = coll_of(spec(is_atom()))
    assert inspect(spec) == "#Norm.CollOf<#Norm.Spec<is_atom()>>"
  end
end
