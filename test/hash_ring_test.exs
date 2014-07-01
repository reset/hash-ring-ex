defmodule HashRingTest do
  use ExUnit.Case

  setup do
    {:ok, ring} = HashRing.start
    {:ok, ring: ring}
  end

  test "adding and dropping a node", ctx do
    assert :ok == HashRing.add(ctx[:ring], "node_one")
    assert :ok == HashRing.drop(ctx[:ring], "node_one")
  end

  test "finding a node", ctx do
    HashRing.add(ctx[:ring], "node_one")
    HashRing.add(ctx[:ring], "node_two")

    assert HashRing.find(ctx[:ring], "my_key") == {:ok, "node_two"}
  end

  test "adding and finding nodes with non-binary terms", ctx do
    HashRing.add(ctx[:ring], :node_one)
    HashRing.add(ctx[:ring], 1)

    assert HashRing.find(ctx[:ring], :my_key) == {:ok, "1"}
  end
end
