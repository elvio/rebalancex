defmodule Rebalancex.Quote do
  @moduledoc """
  Provides real-time prices to a specific symbol using AlphaVantage API
  """

  def price_for(symbol) do
    {:ok, %HTTPoison.Response{status_code: 200, body: body}} = HTTPoison.get(symbol_url(symbol))
    json = Jason.decode!(body)
    {value, ""} = json["Global Quote"]["05. price"] |> Float.parse()
    value
  end

  defp symbol_url(symbol) do
    "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=#{symbol}&apikey=#{api_key()}&datatype=json"
  end

  defp api_key, do: System.get_env("ALPHA_VANTAGE_API_KEY")
end
