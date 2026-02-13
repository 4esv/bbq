import sys
import yfinance as yf

ticker = sys.argv[1] if len(sys.argv) > 1 else "SPY"
period = sys.argv[2] if len(sys.argv) > 2 else "5y"

df = yf.download(ticker, period=period)
df.to_csv(f"data/{ticker}.csv")
print(f"Saved data/{ticker}.csv ({len(df)} rows)")
