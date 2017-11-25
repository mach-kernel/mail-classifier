defmodule PursuitServicesTest do
  use ExUnit.Case
  doctest PursuitServices

  test "greets the world" do
    assert PursuitServices.hello() == :world
  end
end
