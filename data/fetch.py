import sys
import yfinance as yf

ticker = sys.argv[1] if len(sys.argv) > 1 else "SPY"
period = sys.argv[2] if len(sys.argv) > 2 else "5y"

try:
    df = yf.download(ticker, period=period)
except Exception as e:
    print(f"Error downloading {ticker}: {e}", file=sys.stderr)
    sys.exit(1)

if df.empty:
    print(f"No data returned for {ticker} (period={period})", file=sys.stderr)
    sys.exit(1)

df.to_csv(f"data/{ticker}.csv")
print(f"Saved data/{ticker}.csv ({len(df)} rows)")
