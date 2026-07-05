import urllib.request, json

data = json.dumps({
    'username': 'lhdiuhliGEFWIUG',
    'password': 'LOEOIFLFKSKFJ'
}).encode('utf-8')

req = urllib.request.Request(
    'https://web-production-d8671.up.railway.app/app/login',
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
res = urllib.request.urlopen(req)
print(json.dumps(json.loads(res.read()), indent=2))