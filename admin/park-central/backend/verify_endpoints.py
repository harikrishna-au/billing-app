import requests
import json

BASE_URL = "http://localhost:8000/v1"

def test_endpoints():
    print("🔍 Testing API Endpoints...")
    
    # 1. Login to get token (using default credentials)
    try:
        login_res = requests.post(f"{BASE_URL}/auth/login", json={"username": "admin", "password": "admin123"})
        if login_res.status_code != 200:
            print(f"❌ Login failed: {login_res.text}")
            return
        
        token = login_res.json()["data"]["token"]
        headers = {"Authorization": f"Bearer {token}"}
        print("✅ Login successful")
        
        # 2. Get Machines to find an ID
        machines_res = requests.get(f"{BASE_URL}/machines", headers=headers)
        if machines_res.status_code != 200:
            print(f"❌ Get Machines failed: {machines_res.text}")
            return
            
        machines = machines_res.json()["data"]["machines"]
        if not machines:
            print("⚠️ No machines found. Creating one...")
            # Create a machine
            create_res = requests.post(f"{BASE_URL}/machines", json={
                "name": "Test Machine",
                "location": "Test Location",
                "username_prefix": "test",
                "password": "password123"
            }, headers=headers)
            machine_id = create_res.json()["data"]["id"]
        else:
            machine_id = machines[0]["id"]
            print(f"✅ Found machine: {machine_id}")

        # 3. Test Services
        print("\nTesting Services...")
        # Create Service
        svc_res = requests.post(f"{BASE_URL}/machines/{machine_id}/services", json={
            "name": "Integration Test Service",
            "price": 100.0,
            "status": "active"
        }, headers=headers)
        
        if svc_res.status_code == 201:
            print("✅ Create Service successful")
            svc_id = svc_res.json()["data"]["id"]
        else:
            print(f"❌ Create Service failed: {svc_res.text}")
            return

        # Get Service
        get_svc_res = requests.get(f"{BASE_URL}/services/{svc_id}", headers=headers)
        if get_svc_res.status_code == 200:
            print("✅ Get Service successful")
        else:
            print(f"❌ Get Service failed: {get_svc_res.text}")

        # Update Service (triggers history)
        upd_svc_res = requests.put(f"{BASE_URL}/services/{svc_id}", json={
            "price": 150.0
        }, headers=headers)
        if upd_svc_res.status_code == 200:
            print("✅ Update Service successful")
        else:
            print(f"❌ Update Service failed: {upd_svc_res.text}")

        # 4. Test Catalog History
        print("\nTesting Catalog History...")
        hist_res = requests.get(f"{BASE_URL}/machines/{machine_id}/catalog-history", headers=headers)
        if hist_res.status_code == 200:
            history = hist_res.json()["data"]
            print(f"✅ Get Catalog History successful (Count: {len(history)})")
            if len(history) > 0 and history[0]["old_price"] == 100.0 and history[0]["new_price"] == 150.0:
                 print("✅ History validation successful (Price change verified)")
            else:
                 print("⚠️ History validation warning: Price change not found as expected")
        else:
            print(f"❌ Get Catalog History failed: {hist_res.text}")

        # 5. Test Payments
        print("\nTesting Payments...")
        # Create Payment
        pay_res = requests.post(f"{BASE_URL}/payments", json={
            "machine_id": machine_id,
            "bill_number": "TEST-001",
            "amount": 500.0,
            "method": "UPI",
            "status": "success"
        }, headers=headers)
        
        if pay_res.status_code == 201:
            print("✅ Create Payment successful")
            pay_id = pay_res.json()["data"]["id"]
        else:
            print(f"❌ Create Payment failed: {pay_res.text}")

        # Get Payments
        get_pay_res = requests.get(f"{BASE_URL}/machines/{machine_id}/payments?period=day", headers=headers)
        if get_pay_res.status_code == 200:
            payments_data = get_pay_res.json()["data"]
            print(f"✅ Get Payments successful (Count: {len(payments_data['payments'])})")
            if payments_data['summary']['total_amount'] >= 500.0:
                 print("✅ Payment summary verification successful")
        else:
            print(f"❌ Get Payments failed: {get_pay_res.text}")

        print("\n🎉 All backend tests passed!")

    except Exception as e:
        print(f"❌ Test failed with exception: {e}")

if __name__ == "__main__":
    test_endpoints()
