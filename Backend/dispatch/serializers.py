from rest_framework import serializers

from .models import (
    Assignment,
    AuditLog,
    Emergency,
    EmergencyStatus,
    Notification,
    Resource,
    RoadEdge,
    RoadNode,
    Vehicle,
)


class LatLngMixin:
    """
    Accept either latitude/longitude or lat/lng in requests (the design doc
    uses both spellings). Responses always use latitude/longitude.
    """

    def to_internal_value(self, data):
        if hasattr(data, "copy"):
            data = data.copy()
        if "lat" in data and "latitude" not in data:
            data["latitude"] = data.get("lat")
        if "lng" in data and "longitude" not in data:
            data["longitude"] = data.get("lng")
        return super().to_internal_value(data)

    def validate_latitude(self, value):
        if value is None or not -90 <= value <= 90:
            raise serializers.ValidationError("Latitude must be between -90 and 90.")
        return value

    def validate_longitude(self, value):
        if value is None or not -180 <= value <= 180:
            raise serializers.ValidationError("Longitude must be between -180 and 180.")
        return value


# ---------------------------------------------------------------------------
# Vehicles & resources
# ---------------------------------------------------------------------------


class VehicleBriefSerializer(serializers.ModelSerializer):
    driver_name = serializers.CharField(source="driver.name", default=None, read_only=True)

    class Meta:
        model = Vehicle
        fields = ["id", "code", "license_plate", "type", "status", "latitude", "longitude", "driver_name"]


class ResourceSerializer(serializers.ModelSerializer):
    vehicle_code = serializers.CharField(source="vehicle.code", default=None, read_only=True)

    class Meta:
        model = Resource
        fields = ["id", "code", "name", "category", "quantity", "unit", "status", "vehicle", "vehicle_code", "updated_at"]
        read_only_fields = ["id", "code", "updated_at"]

    def validate_quantity(self, value):
        if value < 0:
            raise serializers.ValidationError("Quantity cannot be negative.")
        return value


class VehicleSerializer(LatLngMixin, serializers.ModelSerializer):
    driver_name = serializers.CharField(source="driver.name", default=None, read_only=True)
    assigned_emergency_id = serializers.SerializerMethodField()
    assigned_emergency_code = serializers.SerializerMethodField()
    resources = ResourceSerializer(many=True, read_only=True)

    class Meta:
        model = Vehicle
        fields = [
            "id", "code", "license_plate", "type", "status", "latitude", "longitude",
            "driver", "driver_name", "crew_required", "fuel_level", "capabilities", "station_name",
            "assigned_emergency_id", "assigned_emergency_code", "resources",
            "last_location_at", "created_at", "updated_at",
        ]
        read_only_fields = ["id", "code", "last_location_at", "created_at", "updated_at"]
        extra_kwargs = {"latitude": {"required": False}, "longitude": {"required": False}}

    def _active(self, obj):
        cache = getattr(obj, "_active_assignment", "unset")
        if cache == "unset":
            cache = next((a for a in obj.assignments.all() if a.status == Assignment.Status.ACTIVE), None)
            obj._active_assignment = cache
        return cache

    def get_assigned_emergency_id(self, obj):
        a = self._active(obj)
        return a.emergency_id if a else None

    def get_assigned_emergency_code(self, obj):
        a = self._active(obj)
        return a.emergency.code if a else None

    def validate_driver(self, value):
        if value is not None and value.role != "driver":
            raise serializers.ValidationError("Assigned user must have the driver role.")
        return value

    def validate_capabilities(self, value):
        if not isinstance(value, list) or not all(isinstance(x, str) for x in value):
            raise serializers.ValidationError("capabilities must be a list of strings.")
        return value

    def validate_license_plate(self, value):
        return value.strip().upper()

    def create(self, validated):
        # Default location: Karachi centre (same as the Flutter app).
        validated.setdefault("latitude", 24.8607)
        validated.setdefault("longitude", 67.0011)
        return super().create(validated)


class VehicleLocationSerializer(LatLngMixin, serializers.Serializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    status = serializers.ChoiceField(choices=["Available", "Maintenance"], required=False)
    fuel_level = serializers.IntegerField(min_value=0, max_value=100, required=False)


# ---------------------------------------------------------------------------
# Emergencies & assignments
# ---------------------------------------------------------------------------


class AssignmentSerializer(serializers.ModelSerializer):
    vehicle = VehicleBriefSerializer(read_only=True)
    emergency_code = serializers.CharField(source="emergency.code", read_only=True)
    travel_time_min = serializers.FloatField(source="eta_minutes", read_only=True)
    route = serializers.JSONField(source="route_nodes", read_only=True)

    class Meta:
        model = Assignment
        fields = [
            "id", "plan", "emergency", "emergency_code", "vehicle", "status",
            "route", "route_coords", "travel_time_min", "distance_km", "route_unreachable",
            "notes", "assigned_at", "completed_at",
        ]


class EmergencySerializer(LatLngMixin, serializers.ModelSerializer):
    reported_by_name = serializers.CharField(source="reported_by.name", default=None, read_only=True)
    assigned_vehicle = serializers.SerializerMethodField()
    assignments = serializers.SerializerMethodField()

    class Meta:
        model = Emergency
        fields = [
            "id", "code", "category", "status", "severity", "urgency", "people_affected",
            "description", "latitude", "longitude", "location_label",
            "priority_score", "vehicles_required", "allocation_code", "allocation_reason",
            "reported_by", "reported_by_name", "assigned_vehicle", "assignments",
            "created_at", "updated_at", "resolved_at",
        ]
        read_only_fields = [
            "id", "code", "status", "priority_score", "vehicles_required", "allocation_code",
            "allocation_reason", "reported_by", "created_at", "updated_at", "resolved_at",
        ]
        extra_kwargs = {
            "severity": {"error_messages": {"max_value": "Severity must be between 1 and 5.",
                                            "min_value": "Severity must be between 1 and 5."}},
            "urgency": {"error_messages": {"max_value": "Urgency must be between 1 and 5.",
                                           "min_value": "Urgency must be between 1 and 5."}},
            "people_affected": {"error_messages": {"min_value": "People affected must be at least 1."}},
            "latitude": {"error_messages": {"required": "Location is required (latitude)."}},
            "longitude": {"error_messages": {"required": "Location is required (longitude)."}},
        }

    def _active(self, obj):
        return [a for a in obj.assignments.all() if a.status == Assignment.Status.ACTIVE]

    def get_assigned_vehicle(self, obj):
        active = self._active(obj)
        return VehicleBriefSerializer(active[0].vehicle).data if active else None

    def get_assignments(self, obj):
        return AssignmentSerializer(self._active(obj), many=True).data

    def to_internal_value(self, data):
        if hasattr(data, "copy"):
            data = data.copy()
        # Accept "type" (design doc) as an alias of "category" (Flutter app).
        if "type" in data and "category" not in data:
            data["category"] = data.get("type")
        if isinstance(data.get("category"), str):
            data["category"] = data["category"].upper()
        return super().to_internal_value(data)


class EmergencyUpdateSerializer(serializers.ModelSerializer):
    """PUT/PATCH by dispatcher/admin: correct severity/urgency/people/description/location label."""

    class Meta:
        model = Emergency
        fields = ["severity", "urgency", "people_affected", "description", "location_label", "category"]


class StatusChangeSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=EmergencyStatus.choices)


class ManualAssignSerializer(serializers.Serializer):
    vehicle_id = serializers.IntegerField()
    notes = serializers.CharField(required=False, allow_blank=True, default="", max_length=500)


# ---------------------------------------------------------------------------
# Roads
# ---------------------------------------------------------------------------


class RoadNodeSerializer(LatLngMixin, serializers.ModelSerializer):
    class Meta:
        model = RoadNode
        fields = ["id", "name", "latitude", "longitude"]


class RoadEdgeSerializer(serializers.ModelSerializer):
    latitude = serializers.SerializerMethodField()
    longitude = serializers.SerializerMethodField()
    road_name = serializers.CharField(source="name", read_only=True)
    reason = serializers.CharField(source="block_reason", read_only=True)

    class Meta:
        model = RoadEdge
        fields = [
            "id", "name", "road_name", "from_node", "to_node", "travel_time", "distance_km",
            "two_way", "is_blocked", "block_reason", "reason", "latitude", "longitude", "updated_at",
        ]
        read_only_fields = ["id", "is_blocked", "block_reason", "updated_at"]

    # Midpoint of the road segment - used as the marker position on the map.
    def get_latitude(self, obj):
        return round((obj.from_node.latitude + obj.to_node.latitude) / 2, 6)

    def get_longitude(self, obj):
        return round((obj.from_node.longitude + obj.to_node.longitude) / 2, 6)

    def validate_travel_time(self, value):
        if value is None or value < 0:
            raise serializers.ValidationError("travel_time must be a non-negative number of minutes.")
        return value

    def validate(self, attrs):
        if attrs.get("from_node") and attrs.get("from_node") == attrs.get("to_node"):
            raise serializers.ValidationError("from_node and to_node must be different.")
        return attrs


class RoadBlockSerializer(serializers.Serializer):
    is_blocked = serializers.BooleanField()
    reason = serializers.CharField(required=False, allow_blank=True, default="", max_length=500)


class RouteRequestSerializer(serializers.Serializer):
    vehicle_id = serializers.IntegerField(required=False)
    emergency_id = serializers.IntegerField(required=False)
    from_lat = serializers.FloatField(required=False, min_value=-90.0, max_value=90.0)
    from_lng = serializers.FloatField(required=False, min_value=-180.0, max_value=180.0)
    to_lat = serializers.FloatField(required=False, min_value=-90.0, max_value=90.0)
    to_lng = serializers.FloatField(required=False, min_value=-180.0, max_value=180.0)

    def validate(self, attrs):
        has_ids = "vehicle_id" in attrs and "emergency_id" in attrs
        has_points = all(k in attrs for k in ("from_lat", "from_lng", "to_lat", "to_lng"))
        if not (has_ids or has_points):
            raise serializers.ValidationError(
                "Provide {vehicle_id, emergency_id} or {from_lat, from_lng, to_lat, to_lng}.")
        return attrs


# ---------------------------------------------------------------------------
# Notifications & audit
# ---------------------------------------------------------------------------


class NotificationSerializer(serializers.ModelSerializer):
    is_read = serializers.SerializerMethodField()
    emergency_code = serializers.CharField(source="emergency.code", default=None, read_only=True)

    class Meta:
        model = Notification
        fields = ["id", "title", "message", "target_role", "emergency", "emergency_code", "is_read", "created_at"]

    def get_is_read(self, obj):
        return obj.id in self.context.get("read_ids", set())


class AuditLogSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source="actor.name", default=None, read_only=True)

    class Meta:
        model = AuditLog
        fields = ["id", "event", "actor", "actor_name", "details", "created_at"]
