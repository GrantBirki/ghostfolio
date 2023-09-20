# Schwab

Go to each brokerage account and do the following:

1. Click the name
2. Click the `history` tab
3. Click `export`

You should get some data in a CSV like this:

```csv
"Date","Action","Symbol","Description","Quantity","Price","Fees & Comm","Amount"
"06/27/2023","Reinvest Shares","SCHA","SCHWAB US SMALL CAP ETF","0.0155","$42.4901","","-$0.66"
"06/27/2023","Reinvest Shares","SCHB","SCHWAB US BROAD MARKET ETF","0.1328","$50.4525","","-$6.70"
```

Now you can parse it with `script/format <path_to_csv> <account_id>`
