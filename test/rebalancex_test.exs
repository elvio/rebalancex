defmodule RebalancexTest do
  use ExUnit.Case
  doctest Rebalancex

  defmodule Fake.Quote do
    def price_for("IAU"), do: 150
    def price_for("TLT"), do: 100
    def price_for("VGSH"), do: 100
    def price_for("VTI"), do: 50
  end

  describe "rebalance_portfolio/2" do
    test "sell overweight and buys underweight" do
      allocations = %{"IAU" => 10, "TLT" => 10, "VGSH" => 10, "VTI" => 10}
      orders = Rebalancex.rebalance_portfolio(allocations, Fake.Quote)

      assert [:sell, "IAU", 4] in orders
      assert [:sell, "TLT", 1] in orders
      assert [:sell, "VGSH", 1] in orders
      assert [:buy, "VTI", 8] in orders
    end
  end
end
