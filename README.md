# CloudflareBestIPTencentDNS
1. Get current IP from Tencent DNS and test its speed
2. Choose a best IP from ip.txt
3. Compare current IP with best IP, update it to Tencent DNS if the chosen one is better

# Usage

```shell
./cf.sh -i "API_ID" -k "API_KEY" -h "HOST" -u 1
```

## Add proxycf.sh

Find the best ip to proxy cloudflare website.

Cloudflare worker cannot visit websites based on cloudflare, so the worker needs other cdn to proxy these websites.

```shell
./proxycf.sh -i "API_ID" -k "API_KEY" -h "HOST" -u 1
```

