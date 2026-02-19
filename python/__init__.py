import akshare as ak
name = 'sh600751'
df = ak.stock_zh_a_minute(symbol=name, period='1', adjust="qfq")
df.to_csv(name + ".csv")
