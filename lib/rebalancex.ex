defmodule Rebalancex do
  alias Rebalancex.Quote

  @underweight 0.25
  @overweight 0.27

  def rebalance_portfolio(allocations, quote_service \\ Quote) do
    portfolio = %{cash: 0, allocations: allocations}
    prices = get_prices(allocations, quote_service)

    new_portfolio = do_rebalance_portfolio(portfolio, prices)
    create_order(portfolio, new_portfolio)
  end

  defp do_rebalance_portfolio(portfolio, prices) do
    positions = get_positions(portfolio.allocations, prices)
    weights = get_weights(positions)

    underweight_symbol = get_underweight(weights)
    overweight_symbol = get_overweight(weights)

    portfolio
    |> maybe_buy_underweight(underweight_symbol, prices)
    |> maybe_sell_overweight(overweight_symbol, prices)
    |> maybe_rebalance_again(underweight_symbol, overweight_symbol, prices)
  end

  defp get_prices(allocations, quote_service) do
    allocations
    |> Enum.reduce(%{}, fn {symbol, _}, acc ->
      Map.put(acc, symbol, quote_service.price_for(symbol))
    end)
  end

  defp get_price(prices, symbol) do
    Map.fetch!(prices, symbol)
  end

  defp get_positions(portfolio, prices) do
    portfolio
    |> Enum.reduce(%{}, fn {symbol_name, units}, acc ->
      Map.put(acc, symbol_name, get_price(prices, symbol_name) * units)
    end)
  end

  defp get_weights(positions) do
    total_value = Enum.reduce(positions, 0, fn {_, position}, acc -> position + acc end)

    positions
    |> Enum.reduce(%{}, fn {symbol_name, position}, acc ->
      Map.put(acc, symbol_name, position / total_value)
    end)
  end

  defp get_underweight(weights) do
    {symbol, _weight} =
      weights
      |> Enum.filter(fn {_, value} -> value < @underweight end)
      |> Enum.min_by(fn {_, value} -> value end, fn -> {nil, nil} end)

    symbol
  end

  defp get_overweight(weights) do
    {symbol, _weight} =
      weights
      |> Enum.filter(fn {_, value} -> value > @overweight end)
      |> Enum.max_by(fn {_, value} -> value end, fn -> {nil, nil} end)

    symbol
  end

  defp maybe_buy_underweight(portfolio, nil, _) do
    portfolio
  end

  defp maybe_buy_underweight(portfolio, symbol, prices) do
    price = get_price(prices, symbol)
    maybe_buy_underweight(portfolio, symbol, price, portfolio.cash)
  end

  defp maybe_buy_underweight(portfolio, symbol, price, cash) when cash > price do
    portfolio
    |> incr(symbol)
    |> withdraw(price)
  end

  defp maybe_buy_underweight(portfolio, _symbol, _price, _cash) do
    portfolio
  end

  defp maybe_sell_overweight(portfolio, nil, _prices) do
    portfolio
  end

  defp maybe_sell_overweight(portfolio, symbol, prices) do
    price = get_price(prices, symbol)

    portfolio
    |> decr(symbol)
    |> deposit(price)
  end

  defp maybe_rebalance_again(portfolio, nil, nil, _prices) do
    portfolio
  end

  defp maybe_rebalance_again(portfolio, _, _, prices) do
    do_rebalance_portfolio(portfolio, prices)
  end

  defp incr(%{allocations: allocations} = portfolio, symbol) do
    new_allocations = Map.put(allocations, symbol, allocations[symbol] + 1)
    %{portfolio | allocations: new_allocations}
  end

  defp decr(%{allocations: allocations} = portfolio, symbol) do
    new_allocations = Map.put(allocations, symbol, allocations[symbol] - 1)
    %{portfolio | allocations: new_allocations}
  end

  defp deposit(%{cash: cash} = portfolio, amount), do: %{portfolio | cash: cash + amount}

  defp withdraw(%{cash: cash} = portfolio, amount), do: %{portfolio | cash: cash - amount}

  defp create_order(%{allocations: old_allocations}, %{allocations: new_allocations}) do
    Enum.map(old_allocations, fn {symbol, old_units} ->
      cond do
        new_allocations[symbol] > old_units ->
          [:buy, symbol, new_allocations[symbol] - old_units]

        new_allocations[symbol] < old_units ->
          [:sell, symbol, old_units - new_allocations[symbol]]

        true ->
          [:keep, symbol]
      end
    end)
  end
end
