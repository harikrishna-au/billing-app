#!/usr/bin/env python3
"""
Comprehensive endpoint testing script for Billing Machine API
Tests all endpoints and generates a detailed report
"""

import requests
import json
from datetime import datetime
from typing import Dict, List, Tuple

BASE_URL = "http://localhost:8000"
API_V1 = f"{BASE_URL}/v1"

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

class EndpointTester:
    def __init__(self):
        self.results = []
        self.access_token = None
        self.refresh_token = None
        self.machine_id = None
        self.service_id = None
        self.payment_id = None
        
    def test_endpoint(self, method: str, endpoint: str, name: str, 
                     data=None, headers=None, params=None, expected_status=200, use_base=False) -> Dict:
        """Test a single endpoint and return result"""
        # For root and health endpoints, use BASE_URL instead of API_V1
        if use_base:
            url = f"{BASE_URL}{endpoint}"
        else:
            url = f"{API_V1}{endpoint}" if not endpoint.startswith('http') else endpoint
        
        try:
            if method == "GET":
                response = requests.get(url, headers=headers, params=params, timeout=10)
            elif method == "POST":
                response = requests.post(url, json=data, headers=headers, params=params, timeout=10)
            elif method == "PUT":
                response = requests.put(url, json=data, headers=headers, params=params, timeout=10)
            elif method == "PATCH":
                response = requests.patch(url, json=data, headers=headers, params=params, timeout=10)
            elif method == "DELETE":
                response = requests.delete(url, headers=headers, params=params, timeout=10)
            else:
                return {"success": False, "error": f"Unknown method: {method}"}
            
            success = response.status_code == expected_status
            result = {
                "name": name,
                "method": method,
                "endpoint": endpoint,
                "status_code": response.status_code,
                "expected_status": expected_status,
                "success": success,
                "response_time_ms": int(response.elapsed.total_seconds() * 1000),
            }
            
            try:
                result["response_data"] = response.json()
            except:
                result["response_data"] = response.text[:200]
            
            return result
            
        except requests.exceptions.ConnectionError:
            return {
                "name": name,
                "method": method,
                "endpoint": endpoint,
                "success": False,
                "error": "Connection refused - Server not running?"
            }
        except Exception as e:
            return {
                "name": name,
                "method": method,
                "endpoint": endpoint,
                "success": False,
                "error": str(e)
            }
    
    def get_auth_headers(self) -> Dict:
        """Get authorization headers"""
        if self.access_token:
            return {"Authorization": f"Bearer {self.access_token}"}
        return {}
    
    def test_health_endpoints(self):
        """Test health and root endpoints"""
        print(f"\n{Colors.BOLD}=== TESTING HEALTH & ROOT ENDPOINTS ==={Colors.RESET}")
        
        # Test root
        result = self.test_endpoint("GET", "/", "Root Endpoint", expected_status=200, use_base=True)
        self.results.append(result)
        self.print_result(result)
        
        # Test health
        result = self.test_endpoint("GET", "/health", "Health Check", expected_status=200, use_base=True)
        self.results.append(result)
        self.print_result(result)
    
    def test_auth_endpoints(self):
        """Test all authentication endpoints"""
        print(f"\n{Colors.BOLD}=== TESTING AUTHENTICATION ENDPOINTS ==={Colors.RESET}")
        
        # Test machine login
        login_data = {
            "username": "admin003",
            "password": "admin"
        }
        result = self.test_endpoint("POST", "/auth/machine-login", "Machine Login", 
                                   data=login_data, expected_status=200)
        self.results.append(result)
        self.print_result(result)
        
        if result.get("success") and result.get("response_data"):
            data = result["response_data"].get("data", {})
            self.access_token = data.get("token")
            self.refresh_token = data.get("refresh_token")
            machine = data.get("machine", {})
            self.machine_id = machine.get("id")
            print(f"  {Colors.GREEN}✓ Saved token and machine_id: {self.machine_id[:8]}...{Colors.RESET}")
        
        # Test /me endpoint
        result = self.test_endpoint("GET", "/auth/me", "Get Current User", 
                                   headers=self.get_auth_headers(), expected_status=200)
        self.results.append(result)
        self.print_result(result)
        
        # Test token refresh
        if self.refresh_token:
            refresh_data = {"refresh_token": self.refresh_token}
            result = self.test_endpoint("POST", "/auth/refresh", "Token Refresh", 
                                       data=refresh_data, expected_status=200)
            self.results.append(result)
            self.print_result(result)
        
        # Test logout
        result = self.test_endpoint("POST", "/auth/logout", "Logout", 
                                   headers=self.get_auth_headers(), expected_status=200)
        self.results.append(result)
        self.print_result(result)
        
        # Re-login for subsequent tests
        result = self.test_endpoint("POST", "/auth/machine-login", "Re-login for tests", 
                                   data=login_data, expected_status=200)
        if result.get("success"):
            data = result["response_data"].get("data", {})
            self.access_token = data.get("token")
    
    def test_machine_endpoints(self):
        """Test machine CRUD endpoints"""
        print(f"\n{Colors.BOLD}=== TESTING MACHINE ENDPOINTS ==={Colors.RESET}")
        
        # Get all machines
        result = self.test_endpoint("GET", "/machines", "Get All Machines", 
                                   headers=self.get_auth_headers(), expected_status=200)
        self.results.append(result)
        self.print_result(result)
        
        # Get single machine
        if self.machine_id:
            result = self.test_endpoint("GET", f"/machines/{self.machine_id}", 
                                       "Get Machine By ID", 
                                       headers=self.get_auth_headers(), expected_status=200)
            self.results.append(result)
            self.print_result(result)
            
            # Update machine status
            update_data = {"status": "online"}
            result = self.test_endpoint("PATCH", f"/machines/{self.machine_id}/status", 
                                       "Update Machine Status", 
                                       data=update_data,
                                       headers=self.get_auth_headers(), expected_status=200)
            self.results.append(result)
            self.print_result(result)
    
    def test_service_endpoints(self):
        """Test service/catalog endpoints"""
        print(f"\n{Colors.BOLD}=== TESTING SERVICE ENDPOINTS ==={Colors.RESET}")
        
        if not self.machine_id:
            print(f"  {Colors.YELLOW}⚠ Skipping - no machine_id{Colors.RESET}")
            return
        
        # Get services by machine
        result = self.test_endpoint("GET", f"/machines/{self.machine_id}/services", 
                                   "Get Services By Machine", 
                                   headers=self.get_auth_headers(), expected_status=200)
        self.results.append(result)
        self.print_result(result)
        
        # Get active services
        result = self.test_endpoint("GET", f"/machines/{self.machine_id}/services/active", 
                                   "Get Active Services", 
                                   headers=self.get_auth_headers(), expected_status=200)
        self.results.append(result)
        self.print_result(result)
        
        # Store first service ID if available
        if result.get("success") and result.get("response_data"):
            services = result["response_data"].get("data", [])
            if services and len(services) > 0:
                self.service_id = services[0].get("id")
                
                # Get service by ID
                result = self.test_endpoint("GET", f"/services/{self.service_id}", 
                                           "Get Service By ID", 
                                           headers=self.get_auth_headers(), expected_status=200)
                self.results.append(result)
                self.print_result(result)
    
    def test_payment_endpoints(self):
        """Test payment endpoints"""
        print(f"\n{Colors.BOLD}=== TESTING PAYMENT ENDPOINTS ==={Colors.RESET}")
        
        # Get all payments
        result = self.test_endpoint("GET", "/payments", "Get All Payments", 
                                   headers=self.get_auth_headers(), expected_status=200)
        self.results.append(result)
        self.print_result(result)
        
        if self.machine_id:
            # Get payments by machine
            result = self.test_endpoint("GET", f"/machines/{self.machine_id}/payments", 
                                       "Get Payments By Machine", 
                                       headers=self.get_auth_headers(), expected_status=200)
            self.results.append(result)
            self.print_result(result)
            
            # Create payment
            payment_data = {
                "machine_id": self.machine_id,
                "bill_number": f"TEST-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                "amount": 100.00,
                "method": "UPI",
                "status": "success"
            }
            result = self.test_endpoint("POST", "/payments", "Create Payment", 
                                       data=payment_data,
                                       headers=self.get_auth_headers(), expected_status=201)
            self.results.append(result)
            self.print_result(result)
            
            if result.get("success") and result.get("response_data"):
                self.payment_id = result["response_data"].get("data", {}).get("id")
                
                # Get payment by ID
                if self.payment_id:
                    result = self.test_endpoint("GET", f"/payments/{self.payment_id}", 
                                               "Get Payment By ID", 
                                               headers=self.get_auth_headers(), expected_status=200)
                    self.results.append(result)
                    self.print_result(result)
    
    def test_analytics_endpoints(self):
        """Test analytics and dashboard endpoints"""
        print(f"\n{Colors.BOLD}=== TESTING ANALYTICS & DASHBOARD ENDPOINTS ==={Colors.RESET}")
        
        # Test dashboard
        result = self.test_endpoint("GET", "/dashboard", "Get Dashboard Stats", 
                                   headers=self.get_auth_headers(), expected_status=200)
        self.results.append(result)
        self.print_result(result)
        
        # Test analytics
        result = self.test_endpoint("GET", "/analytics", "Get Analytics", 
                                   headers=self.get_auth_headers(), expected_status=200)
        self.results.append(result)
        self.print_result(result)
    
    def test_sync_endpoints(self):
        """Test sync endpoints"""
        print(f"\n{Colors.BOLD}=== TESTING SYNC ENDPOINTS ==={Colors.RESET}")
        
        if not self.machine_id:
            print(f"  {Colors.YELLOW}⚠ Skipping - no machine_id{Colors.RESET}")
            return
        
        # Test sync status
        result = self.test_endpoint("GET", f"/sync/status/{self.machine_id}", 
                                   "Get Sync Status", 
                                   headers=self.get_auth_headers(), expected_status=200)
        self.results.append(result)
        self.print_result(result)
        
        # Test sync pull
        result = self.test_endpoint("POST", f"/sync/pull?machine_id={self.machine_id}", 
                                   "Sync Pull (Download)", 
                                   headers=self.get_auth_headers(), expected_status=200)
        self.results.append(result)
        self.print_result(result)
    
    def test_logs_endpoints(self):
        """Test logs and catalog history endpoints"""
        print(f"\n{Colors.BOLD}=== TESTING LOGS ENDPOINTS ==={Colors.RESET}")
        
        # Test logs
        result = self.test_endpoint("GET", "/logs", "Get Logs", 
                                   headers=self.get_auth_headers(), expected_status=200)
        self.results.append(result)
        self.print_result(result)
        
        # Test catalog history
        result = self.test_endpoint("GET", "/catalog-history", "Get Catalog History", 
                                   headers=self.get_auth_headers(), expected_status=200)
        self.results.append(result)
        self.print_result(result)
    
    def print_result(self, result: Dict):
        """Print a single test result"""
        status_icon = f"{Colors.GREEN}✓{Colors.RESET}" if result.get("success") else f"{Colors.RED}✗{Colors.RESET}"
        name = result.get("name", "Unknown")
        method = result.get("method", "")
        endpoint = result.get("endpoint", "")
        
        print(f"  {status_icon} {method:6} {endpoint:40} - {name}")
        
        if not result.get("success"):
            if "error" in result:
                print(f"    {Colors.RED}Error: {result['error']}{Colors.RESET}")
            elif "status_code" in result:
                print(f"    {Colors.RED}Status: {result['status_code']} (expected {result['expected_status']}){Colors.RESET}")
        else:
            response_time = result.get("response_time_ms", 0)
            print(f"    {Colors.BLUE}Response time: {response_time}ms{Colors.RESET}")
    
    def generate_report(self):
        """Generate final test report"""
        print(f"\n\n{Colors.BOLD}{'='*80}{Colors.RESET}")
        print(f"{Colors.BOLD}ENDPOINT TEST REPORT{Colors.RESET}")
        print(f"{Colors.BOLD}{'='*80}{Colors.RESET}\n")
        
        total = len(self.results)
        passed = sum(1 for r in self.results if r.get("success"))
        failed = total - passed
        pass_rate = (passed / total * 100) if total > 0 else 0
        
        print(f"Total Endpoints Tested: {total}")
        print(f"{Colors.GREEN}Passed: {passed}{Colors.RESET}")
        print(f"{Colors.RED}Failed: {failed}{Colors.RESET}")
        print(f"Pass Rate: {pass_rate:.1f}%\n")
        
        if failed > 0:
            print(f"{Colors.RED}FAILED ENDPOINTS:{Colors.RESET}")
            for result in self.results:
                if not result.get("success"):
                    print(f"  • {result['method']} {result['endpoint']} - {result['name']}")
                    if "error" in result:
                        print(f"    Error: {result['error']}")
                    elif "status_code" in result:
                        print(f"    Status: {result['status_code']} (expected {result['expected_status']})")
            print()
        
        print(f"{Colors.GREEN}WORKING ENDPOINTS:{Colors.RESET}")
        for result in self.results:
            if result.get("success"):
                print(f"  ✓ {result['method']} {result['endpoint']} - {result['name']}")
        
        print(f"\n{Colors.BOLD}{'='*80}{Colors.RESET}")
        
        # Calculate average response time
        response_times = [r.get("response_time_ms", 0) for r in self.results if r.get("success")]
        if response_times:
            avg_time = sum(response_times) / len(response_times)
            print(f"\nAverage Response Time: {avg_time:.0f}ms")
        
        return {
            "total": total,
            "passed": passed,
            "failed": failed,
            "pass_rate": pass_rate
        }

def main():
    print(f"{Colors.BOLD}{Colors.BLUE}")
    print("╔═══════════════════════════════════════════════════════════════╗")
    print("║     BILLING MACHINE API - COMPREHENSIVE ENDPOINT TEST        ║")
    print("╚═══════════════════════════════════════════════════════════════╝")
    print(f"{Colors.RESET}\n")
    
    tester = EndpointTester()
    
    # Run all tests
    tester.test_health_endpoints()
    tester.test_auth_endpoints()
    tester.test_machine_endpoints()
    tester.test_service_endpoints()
    tester.test_payment_endpoints()
    tester.test_analytics_endpoints()
    tester.test_sync_endpoints()
    tester.test_logs_endpoints()
    
    # Generate report
    stats = tester.generate_report()
    
    # Exit with error code if tests failed
    import sys
    sys.exit(0 if stats["failed"] == 0 else 1)

if __name__ == "__main__":
    main()
