import akshare as ak
# 获取 5 分钟线
df = ak.stock_zh_a_hist_min_em(symbol="600000", period='5')
df.to_csv("600000_5m.csv")