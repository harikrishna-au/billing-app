import requests
import json

# Login
resp = requests.post("http://localhost:8000/v1/auth/machine-login", json={"username": "admin003", "password": "admin"})
print("Login Response:", resp.status_code)
data = resp.json()
print(json.dumps(data, indent=2))

token = data['data']['token']
print(f"\nToken: {token[:50]}...")

# Test with token
headers = {"Authorization": f"Bearer {token}"}
resp2 = requests.get("http://localhost:8000/v1/machines", headers=headers)
print(f"\nMachines Response: {resp2.status_code}")
print(json.dumps(resp2.json(), indent=2))
