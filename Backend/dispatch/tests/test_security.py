from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from accounts.models import Role, User
from dispatch.models import Emergency, EmergencyCategory, EmergencyStatus, RoadEdge, RoadNode, Vehicle


class SecurityHardeningTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.citizen = User.objects.create_user(
            name="Citizen One",
            email="citizen@resq.pk",
            password="Password123",
            role=Role.CITIZEN,
        )
        self.dispatcher = User.objects.create_user(
            name="Dispatcher One",
            email="dispatcher@resq.pk",
            password="Password123",
            role=Role.DISPATCHER,
        )
        self.admin = User.objects.create_superuser(
            name="Admin One",
            email="admin@resq.pk",
            password="Password123",
            role=Role.ADMIN,
        )

    def test_security_headers_present_in_responses(self):
        """Verify OWASP recommended security headers are served."""
        r = self.client.get("/api/health/")
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertEqual(r.headers.get("X-Content-Type-Options"), "nosniff")
        self.assertEqual(r.headers.get("X-Frame-Options"), "DENY")

    def test_citizen_cannot_access_staff_user_endpoints(self):
        """Citizens cannot list or create accounts in /api/users/."""
        self.client.force_authenticate(user=self.citizen)
        r = self.client.get("/api/users/")
        self.assertEqual(r.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(r.data.get("error"), "FORBIDDEN")

    def test_route_endpoint_validates_coordinate_bounds(self):
        """Route endpoint rejects lat/lng coordinates out of physical bounds."""
        self.client.force_authenticate(user=self.citizen)
        payload = {
            "from_lat": 999.0,  # Invalid latitude > 90
            "from_lng": 67.0,
            "to_lat": 24.8,
            "to_lng": 67.1,
        }
        r = self.client.post("/api/route/", payload, format="json")
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(r.data.get("error"), "VALIDATION_ERROR")

    def test_query_params_non_integer_handled_safely(self):
        """Malformed query params return 400 BadRequest instead of unhandled 500 error."""
        self.client.force_authenticate(user=self.dispatcher)
        r_plan = self.client.get("/api/plan/history/?limit=not-a-number")
        self.assertEqual(r_plan.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(r_plan.data.get("error"), "VALIDATION_ERROR")

        r_reports = self.client.get("/api/reports/summary/?days=invalid")
        self.assertEqual(r_reports.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(r_reports.data.get("error"), "VALIDATION_ERROR")

        r_notif = self.client.get("/api/notifications/?limit=bad")
        self.assertEqual(r_notif.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(r_notif.data.get("error"), "VALIDATION_ERROR")

    def test_citizen_cannot_trigger_allocation_or_replan(self):
        """Citizens are forbidden from triggering resource allocation."""
        self.client.force_authenticate(user=self.citizen)
        r_alloc = self.client.post("/api/allocate/", {}, format="json")
        self.assertEqual(r_alloc.status_code, status.HTTP_403_FORBIDDEN)

        r_recalc = self.client.post("/api/plan/recalculate/", {}, format="json")
        self.assertEqual(r_recalc.status_code, status.HTTP_403_FORBIDDEN)

    def test_road_block_reason_length_limit(self):
        """Road block reason enforces input boundary length caps."""
        self.client.force_authenticate(user=self.dispatcher)
        n1 = RoadNode.objects.create(name="N1", latitude=24.86, longitude=67.00)
        n2 = RoadNode.objects.create(name="N2", latitude=24.86, longitude=67.01)
        edge = RoadEdge.objects.create(name="Test Road", from_node=n1, to_node=n2, travel_time=5, distance_km=1.2)
        huge_reason = "A" * 600
        payload = {"is_blocked": True, "reason": huge_reason}
        r = self.client.post(f"/api/roads/{edge.id}/block/", payload, format="json")
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(r.data.get("error"), "VALIDATION_ERROR")
