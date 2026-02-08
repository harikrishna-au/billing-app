import requests
import json

BASE_URL = "http://localhost:8000/v1"

def test_logs():
    print("🔍 Testing Logs API...")
    
    # 1. Login
    try:
        login_res = requests.post(f"{BASE_URL}/auth/login", json={"username": "admin", "password": "admin123"})
        if login_res.status_code != 200:
            print(f"❌ Login failed: {login_res.text}")
            return
        
        token = login_res.json()["data"]["token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # 2. Get Machine ID
        machines_res = requests.get(f"{BASE_URL}/machines", headers=headers)
        if machines_res.status_code != 200:
            print(f"❌ Get Machines failed: {machines_res.text}")
            return
            
        machines = machines_res.json()["data"]["machines"]
        if not machines:
            print("⚠️ No machines found. Skipping log test.")
            return

        machine_id = machines[0]["id"]
        print(f"✅ Found machine: {machine_id}")

        # 3. Create Log
        print("\n📝 Creating Log Entry...")
        create_res = requests.post(f"{BASE_URL}/machines/{machine_id}/logs", json={
            "action": "System Reboot",
            "details": "Automated weekly reboot",
            "type": "system"
        }, headers=headers)
        
        if create_res.status_code == 201:
            print("✅ Log created successfully")
        else:
            print(f"❌ Log creation failed: {create_res.text}")
            return

        # 4. Get Machine Logs
        print("\n📊 Fetching Machine Logs...")
        get_res = requests.get(f"{BASE_URL}/machines/{machine_id}/logs", headers=headers)
        if get_res.status_code == 200:
            data = get_res.json()["data"]
            logs = data["logs"]
            print(f"✅ Fetched {len(logs)} logs")
            if len(logs) > 0 and logs[0]["action"] == "System Reboot":
                print("✅ Log verification successful (Content match)")
        else:
            print(f"❌ Fetch logs failed: {get_res.text}")

        # 5. Get Recent Logs (Global)
        print("\n🌐 Fetching Global Recent Logs...")
        recent_res = requests.get(f"{BASE_URL}/logs/recent", headers=headers)
        if recent_res.status_code == 200:
            recent_logs = recent_res.json()["data"]
            print(f"✅ Fetched {len(recent_logs)} recent logs")
        else:
            print(f"❌ Fetch recent logs failed: {recent_res.text}")

    except Exception as e:
        print(f"❌ Test failed with exception: {e}")

if __name__ == "__main__":
    test_logs()
