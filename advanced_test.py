import requests
import time

API_URL = "https://family-academy-backend-a12l.onrender.com/api/v1"

class NotificationTester:
    def __init__(self):
        self.admin_token = None
        # Use the EXACT device ID that's in the database
        self.device_id = "ANDROID_548436410"
        
    def login_admin(self):
        print("\n🔑 Logging in as admin...")
        response = requests.post(f"{API_URL}/auth/admin-login", json={
            "username": "admin",
            "password": "admin123"
        })
        if response.status_code == 200:
            self.admin_token = response.json()['data']['token']
            print("✅ Admin login successful")
            return True
        print("❌ Admin login failed")
        return False
    
    def test_user_login(self, username, password):
        """Test if user can login with the correct deviceId"""
        print(f"\n🔐 Testing login for {username}...")
        try:
            # Use the SAME device ID for all users (matches database)
            response = requests.post(f"{API_URL}/auth/student-login", json={
                "username": username,
                "password": password,
                "deviceId": self.device_id,  # Same device ID for all
                "fcmToken": f"TEST_FCM_{username}"
            })
            
            print(f"Status: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                print(f"✅ SUCCESS! User: {data['data']['user']['username']}")
                print(f"   Account Status: {data['data']['user']['account_status']}")
                return data['data']['token']
            else:
                print(f"❌ Failed: {response.status_code}")
                print(f"Response: {response.text[:200]}")
                return None
        except Exception as e:
            print(f"❌ Error: {e}")
            return None
    
    def test_notifications(self, token, username):
        """Check user's notifications"""
        try:
            response = requests.get(
                f"{API_URL}/notifications/my-notifications",
                headers={"Authorization": f"Bearer {token}"}
            )
            if response.status_code == 200:
                notifs = response.json()['data']
                print(f"   📱 {username} has {len(notifs)} notifications")
                if notifs:
                    print(f"      Latest: {notifs[0]['title']}")
                return len(notifs)
        except Exception as e:
            print(f"   ❌ Failed to get notifications: {e}")
        return 0
    
    def run_tests(self):
        print("="*60)
        print("🔬 TESTING USER LOGINS WITH FIXED DEVICE ID")
        print("="*60)
        
        # Test users with their passwords
        test_users = [
            ('kalaabale', 'Kalaab1!'),
            ('bravery', 'Kalaab1!'),
            ('test_paid_1', 'Kalaab1!'),
            ('test_paid_2', 'Kalaab1!'),
            ('test_progress_1', 'Kalaab1!'),
            ('test_streak_1', 'Kalaab1!'),
            ('test_unpaid_1', 'Kalaab1!'),
            ('test_parent_1', 'Kalaab1!'),
        ]
        
        successful_logins = 0
        total_notifications = 0
        
        for username, password in test_users:
            token = self.test_user_login(username, password)
            if token:
                successful_logins += 1
                count = self.test_notifications(token, username)
                total_notifications += count
            time.sleep(1)  # Small delay to avoid rate limiting
        
        print("\n" + "="*60)
        print(f"📊 RESULTS: {successful_logins}/{len(test_users)} successful logins")
        print(f"📱 Total notifications: {total_notifications}")
        print("="*60)

if __name__ == "__main__":
    tester = NotificationTester()
    tester.run_tests()