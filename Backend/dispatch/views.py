from datetime import timedelta

from django.db import transaction
from django.db.models import Avg, Count, Prefetch, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.pagination import LimitOffsetPagination
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import Role, User
from accounts.permissions import IsAdmin, IsDispatcherOrAdmin, IsStaffRole

from .exceptions import BadRequest, Conflict, Unreachable
from .models import (
    ACTIVE_EMERGENCY_STATUSES,
    Assignment,
    AuditLog,
    Emergency,
    EmergencyStatus,
    Notification,
    NotificationRead,
    Plan,
    Resource,
    ResourceCategory,
    RoadEdge,
    RoadNode,
    Vehicle,
    VehicleLocationLog,
    VehicleStatus,
)
from .serializers import (
    AssignmentSerializer,
    AuditLogSerializer,
    EmergencySerializer,
    EmergencyUpdateSerializer,
    ManualAssignSerializer,
    NotificationSerializer,
    ResourceSerializer,
    RoadBlockSerializer,
    RoadEdgeSerializer,
    RoadNodeSerializer,
    RouteRequestSerializer,
    StatusChangeSerializer,
    VehicleBriefSerializer,
    VehicleLocationSerializer,
    VehicleSerializer,
)
from .services import planner
from .services.audit import audit
from .services.graph import get_graph, invalidate
from .services.notify import notify

ACTIVE = Assignment.Status.ACTIVE


def _active_assignments_prefetch():
    return Prefetch(
        "assignments",
        queryset=Assignment.objects.filter(status=ACTIVE).select_related("vehicle", "vehicle__driver", "emergency"),
    )


def _bool_param(request, name):
    value = request.query_params.get(name)
    if value is None:
        return None
    return value.strip().lower() in ("1", "true", "yes")


# ---------------------------------------------------------------------------
# Emergencies
# ---------------------------------------------------------------------------


class EmergencyViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, mixins.CreateModelMixin,
                       mixins.UpdateModelMixin, viewsets.GenericViewSet):
    """
    GET    /api/emergencies/?status=REPORTED,ASSIGNED&category=FIRE&mine=true&active=true&q=text
    POST   /api/emergencies/                  register emergency (FR-01)
    GET    /api/emergencies/{id}/
    PUT    /api/emergencies/{id}/             update severity/urgency/... or status (dispatcher/admin)
    PATCH  /api/emergencies/{id}/status/      mission progression / resolve / cancel
    POST   /api/emergencies/{id}/assign/      manual dispatcher assignment
    GET    /api/emergencies/{id}/candidates/  vehicles ranked by Dijkstra ETA
    """

    serializer_class = EmergencySerializer

    def get_permissions(self):
        if self.action in ("update", "partial_update", "assign", "candidates"):
            return [IsDispatcherOrAdmin()]
        return [IsAuthenticated()]

    def get_queryset(self):
        user = self.request.user
        qs = Emergency.objects.select_related("reported_by").prefetch_related(_active_assignments_prefetch())
        if user.role == Role.CITIZEN:
            qs = qs.filter(reported_by=user)
        elif user.role == Role.DRIVER:
            qs = qs.filter(assignments__vehicle__driver=user).distinct()

        p = self.request.query_params
        if p.get("status"):
            statuses = [s.strip().upper() for s in p["status"].split(",")]
            statuses = [EmergencyStatus.REPORTED if s == "PENDING" else s for s in statuses]
            qs = qs.filter(status__in=statuses)
        if _bool_param(self.request, "active"):
            qs = qs.filter(status__in=ACTIVE_EMERGENCY_STATUSES)
        if p.get("category"):
            qs = qs.filter(category=p["category"].upper())
        if _bool_param(self.request, "mine"):
            qs = qs.filter(reported_by=user)
        if p.get("q"):
            q = p["q"]
            qs = qs.filter(Q(description__icontains=q) | Q(location_label__icontains=q) | Q(code__icontains=q))
        if p.get("ordering") == "priority":
            qs = qs.order_by("-priority_score", "created_at")
        return qs

    def create(self, request, *args, **kwargs):
        if request.user.role == Role.DRIVER:
            raise Conflict("Drivers cannot register emergencies.")
        s = self.get_serializer(data=request.data)
        s.is_valid(raise_exception=True)
        em = Emergency(**s.validated_data, reported_by=request.user)
        planner.score_emergency(em)
        em.allocation_reason = (
            f"Awaiting allocation: priority {em.priority_score} "
            f"(severity {em.severity}, urgency {em.urgency}, {em.people_affected} people)."
        )
        em.save()
        audit("EMERGENCY_REGISTERED", request.user, {"emergency": em.code, "priority": em.priority_score})
        notify(f"New Emergency Reported ({em.code})",
               f"New {em.category} emergency at {em.location_label or 'reported location'} requires triage.",
               target_role="dispatcher", emergency=em)
        plan = planner.maybe_auto_allocate(Plan.Reason.NEW_EMERGENCY, request.user)
        em = self.get_queryset().model.objects.prefetch_related(_active_assignments_prefetch()).get(pk=em.pk)
        data = self.get_serializer(em).data
        data["plan_id"] = plan["plan_id"] if plan else None
        return Response(data, status=status.HTTP_201_CREATED)

    def update(self, request, *args, **kwargs):
        em = self.get_object()
        new_status = request.data.get("status")
        s = EmergencyUpdateSerializer(em, data=request.data, partial=kwargs.get("partial", True))
        s.is_valid(raise_exception=True)
        if s.validated_data:
            em = s.save()
            planner.score_emergency(em)
            em.save(update_fields=["priority_score", "vehicles_required", "updated_at"])
            audit("EMERGENCY_UPDATED", request.user, {"emergency": em.code, "fields": list(s.validated_data)})
        if new_status:
            st = StatusChangeSerializer(data={"status": str(new_status).upper()})
            st.is_valid(raise_exception=True)
            _, freed = planner.change_emergency_status(em.id, st.validated_data["status"], request.user)
            if freed:
                planner.maybe_auto_allocate(Plan.Reason.VEHICLE_FREE, request.user)
        return Response(self.get_serializer(self.get_queryset().get(pk=em.pk)).data)

    @action(detail=True, methods=["patch", "post"], url_path="status")
    def change_status(self, request, pk=None):
        em = self.get_object()
        s = StatusChangeSerializer(data={"status": str(request.data.get("status", "")).upper()})
        s.is_valid(raise_exception=True)
        _, freed = planner.change_emergency_status(em.id, s.validated_data["status"], request.user)
        if freed:
            planner.maybe_auto_allocate(Plan.Reason.VEHICLE_FREE, request.user)
        return Response(self.get_serializer(self.get_queryset().get(pk=em.pk)).data)

    @action(detail=True, methods=["post"])
    def assign(self, request, pk=None):
        em = self.get_object()
        s = ManualAssignSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        get_object_or_404(Vehicle, pk=s.validated_data["vehicle_id"])
        planner.assign_manually(em.id, s.validated_data["vehicle_id"], request.user, s.validated_data["notes"])
        return Response(self.get_serializer(self.get_queryset().get(pk=em.pk)).data)

    @action(detail=True, methods=["get"])
    def candidates(self, request, pk=None):
        em = self.get_object()
        return Response({"emergency_id": em.id, "candidates": planner.vehicle_candidates(em)})


# ---------------------------------------------------------------------------
# Vehicles
# ---------------------------------------------------------------------------


class VehicleViewSet(viewsets.ModelViewSet):
    """
    GET    /api/vehicles/?available=true&status=Busy&type=Ambulance
    POST   /api/vehicles/                 (admin)
    PATCH  /api/vehicles/{id}/            (admin/dispatcher) status Available/Maintenance, driver, fuel ...
    DELETE /api/vehicles/{id}/            (admin)
    PATCH  /api/vehicles/{id}/location/   GPS update (driver of the vehicle, dispatcher, admin)
    """

    serializer_class = VehicleSerializer

    def get_permissions(self):
        if self.action in ("create", "destroy"):
            return [IsAdmin()]
        if self.action in ("update", "partial_update"):
            return [IsDispatcherOrAdmin()]
        if self.action == "location":
            return [IsStaffRole()]
        return [IsAuthenticated()]

    def get_queryset(self):
        qs = Vehicle.objects.select_related("driver").prefetch_related(
            _active_assignments_prefetch(), "resources")
        p = self.request.query_params
        if _bool_param(self.request, "available"):
            qs = qs.filter(status=VehicleStatus.AVAILABLE)
        if p.get("status"):
            qs = qs.filter(status__in=[s.strip() for s in p["status"].split(",")])
        if p.get("type"):
            qs = qs.filter(type=p["type"])
        if _bool_param(self.request, "mine"):
            qs = qs.filter(driver=self.request.user)
        return qs

    def perform_create(self, serializer):
        v = serializer.save()
        audit("VEHICLE_CREATED", self.request.user, {"vehicle": v.code})

    def perform_update(self, serializer):
        v = serializer.instance
        new_status = serializer.validated_data.get("status")
        if new_status and new_status != v.status:
            if new_status not in (VehicleStatus.AVAILABLE, VehicleStatus.MAINTENANCE):
                raise BadRequest("Status can only be set to Available or Maintenance; "
                                 "Busy/En Route are managed by assignments.")
            if v.assignments.filter(status=ACTIVE).exists():
                raise Conflict("Vehicle has an active assignment; complete or cancel it first.")
        was_available = v.status == VehicleStatus.AVAILABLE
        v = serializer.save()
        audit("VEHICLE_UPDATED", self.request.user, {"vehicle": v.code, "fields": list(serializer.validated_data)})
        if v.status == VehicleStatus.AVAILABLE and not was_available:
            planner.maybe_auto_allocate(Plan.Reason.VEHICLE_FREE, self.request.user)

    def perform_destroy(self, instance):
        if instance.assignments.filter(status=ACTIVE).exists():
            raise Conflict("Vehicle has an active assignment.")
        audit("VEHICLE_DELETED", self.request.user, {"vehicle": instance.code})
        instance.delete()

    @action(detail=True, methods=["patch", "post"])
    def location(self, request, pk=None):
        v = self.get_object()
        if request.user.role == Role.DRIVER and v.driver_id != request.user.id:
            raise Conflict("You can only update your own vehicle.")
        s = VehicleLocationSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        became_available = False
        with transaction.atomic():
            v = Vehicle.objects.select_for_update().get(pk=v.pk)
            v.latitude, v.longitude = d["latitude"], d["longitude"]
            v.last_location_at = timezone.now()
            if "fuel_level" in d:
                v.fuel_level = d["fuel_level"]
            if d.get("status") and d["status"] != v.status:
                if v.assignments.filter(status=ACTIVE).exists():
                    raise Conflict("Vehicle has an active assignment; status is managed by the mission.")
                became_available = d["status"] == VehicleStatus.AVAILABLE
                v.status = d["status"]
            v.save()
            VehicleLocationLog.objects.create(vehicle=v, latitude=v.latitude, longitude=v.longitude)
            # Refresh ETA/route of the active mission from the new position.
            active = v.assignments.filter(status=ACTIVE).select_related("emergency").first()
            if active:
                route = get_graph().route((v.latitude, v.longitude),
                                          (active.emergency.latitude, active.emergency.longitude))
                planner._apply_route(active, route)
                active.save()
        if became_available:
            planner.maybe_auto_allocate(Plan.Reason.VEHICLE_FREE, request.user)
        return Response({"ok": True, "vehicle": VehicleBriefSerializer(v).data,
                         "eta_minutes": active.eta_minutes if active else None})


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------


class ResourceViewSet(viewsets.ModelViewSet):
    """
    GET /api/resources/?category=Crew&vehicle=1
    POST/PUT/PATCH/DELETE (admin; dispatcher may PATCH quantity/status)
    GET /api/resources/summary/  totals per category
    """

    serializer_class = ResourceSerializer

    def get_permissions(self):
        if self.action in ("create", "destroy"):
            return [IsAdmin()]
        if self.action in ("update", "partial_update"):
            return [IsDispatcherOrAdmin()]
        return [IsAuthenticated()]

    def get_queryset(self):
        qs = Resource.objects.select_related("vehicle")
        p = self.request.query_params
        if p.get("category"):
            qs = qs.filter(category=p["category"])
        if p.get("vehicle"):
            qs = qs.filter(vehicle_id=p["vehicle"])
        if p.get("status"):
            qs = qs.filter(status=p["status"])
        return qs

    def perform_create(self, serializer):
        r = serializer.save()
        audit("RESOURCE_CREATED", self.request.user, {"resource": r.code, "quantity": r.quantity})

    def perform_update(self, serializer):
        r = serializer.save()
        audit("RESOURCE_UPDATED", self.request.user, {"resource": r.code, "quantity": r.quantity, "status": r.status})

    def perform_destroy(self, instance):
        audit("RESOURCE_DELETED", self.request.user, {"resource": instance.code})
        instance.delete()

    @action(detail=False, methods=["get"])
    def summary(self, request):
        out = {c: {"available": 0, "in_use": 0, "depleted": 0, "items": 0} for c in ResourceCategory.values}
        for r in Resource.objects.values("category", "status", "quantity"):
            key = {"Available": "available", "In Use": "in_use", "Depleted": "depleted"}[r["status"]]
            out[r["category"]][key] += r["quantity"]
            out[r["category"]]["items"] += 1
        return Response(out)


# ---------------------------------------------------------------------------
# Roads
# ---------------------------------------------------------------------------


class RoadPagination(LimitOffsetPagination):
    default_limit = 500
    max_limit = 5000


class RoadNodeViewSet(viewsets.ModelViewSet):
    """GET/POST /api/roads/nodes/ - intersections of the road graph."""

    serializer_class = RoadNodeSerializer
    queryset = RoadNode.objects.order_by("id")
    pagination_class = RoadPagination

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [IsAuthenticated()]
        return [IsDispatcherOrAdmin()]

    def perform_create(self, serializer):
        serializer.save()
        invalidate()

    def perform_update(self, serializer):
        serializer.save()
        invalidate()

    def perform_destroy(self, instance):
        instance.delete()
        invalidate()


class RoadEdgeViewSet(viewsets.ModelViewSet):
    """
    GET   /api/roads/?blocked=true&named=true&q=Faisal   (paginated: ?limit=&offset=)
    POST  /api/roads/                 add road edge {from_node, to_node, travel_time, name, distance_km, two_way}
    PATCH /api/roads/{id}/block/      {is_blocked, reason} -> {road, replan_triggered, ...}  (FR-07)
    GET   /api/roads/blocked/         list for the map (blocked + previously blocked roads)
    """

    serializer_class = RoadEdgeSerializer
    pagination_class = RoadPagination

    def get_permissions(self):
        if self.action in ("list", "retrieve", "blocked"):
            return [IsAuthenticated()]
        return [IsDispatcherOrAdmin()]

    def get_queryset(self):
        qs = RoadEdge.objects.select_related("from_node", "to_node").order_by("id")
        b = _bool_param(self.request, "blocked")
        if b is not None:
            qs = qs.filter(is_blocked=b)
        if _bool_param(self.request, "named"):
            qs = qs.exclude(name="")
        if self.request.query_params.get("q"):
            qs = qs.filter(name__icontains=self.request.query_params["q"])
        return qs

    def perform_create(self, serializer):
        e = serializer.save()
        if not e.distance_km:
            from .services.graph import haversine_km

            e.distance_km = round(haversine_km(e.from_node.latitude, e.from_node.longitude,
                                               e.to_node.latitude, e.to_node.longitude), 3)
            e.save(update_fields=["distance_km"])
        invalidate()
        audit("ROAD_CREATED", self.request.user, {"edge": e.id})

    def perform_update(self, serializer):
        serializer.save()
        invalidate()

    def perform_destroy(self, instance):
        instance.delete()
        invalidate()

    @action(detail=False, methods=["get"])
    def blocked(self, request):
        qs = RoadEdge.objects.select_related("from_node", "to_node").filter(
            Q(is_blocked=True) | ~Q(block_reason="")).order_by("-is_blocked", "name", "id")
        return Response(RoadEdgeSerializer(qs, many=True).data)

    @action(detail=True, methods=["patch", "post"])
    def block(self, request, pk=None):
        edge = self.get_object()
        s = RoadBlockSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        blocked = s.validated_data["is_blocked"]
        reason = s.validated_data["reason"]
        changed = edge.is_blocked != blocked
        edge.is_blocked = blocked
        if reason or blocked:
            edge.block_reason = reason or edge.block_reason or "Blocked by dispatcher"
        edge.save()
        result = {"rerouted_assignments": [], "unreachable_assignments": [], "plan_id": None}
        if changed:
            invalidate()
            audit("ROAD_BLOCKED" if blocked else "ROAD_UNBLOCKED", request.user,
                  {"edge": edge.id, "name": edge.name, "reason": edge.block_reason})
            notify("Road Block Alert" if blocked else "Road Reopened",
                   f"{edge.name or 'Road ' + str(edge.id)} {'blocked' if blocked else 'reopened'}"
                   f"{': ' + edge.block_reason if blocked and edge.block_reason else ''}. Routes recalculated.",
                   target_role="driver")
            rerouted, unreachable = planner.reroute_active_assignments(request.user)
            plan = planner.maybe_auto_allocate(Plan.Reason.ROAD_BLOCKED, request.user)
            result = {"rerouted_assignments": rerouted, "unreachable_assignments": unreachable,
                      "plan_id": plan["plan_id"] if plan else None}
        return Response({"road": RoadEdgeSerializer(edge).data, "replan_triggered": changed, **result})


# ---------------------------------------------------------------------------
# Map, planning, routing
# ---------------------------------------------------------------------------


@api_view(["GET"])
def map_data(request):
    """GET /api/map/ - everything the map screens draw (FR-12)."""
    user = request.user
    ems = Emergency.objects.filter(status__in=ACTIVE_EMERGENCY_STATUSES).prefetch_related(
        _active_assignments_prefetch()).select_related("reported_by")
    if user.role == Role.CITIZEN:
        ems = ems.filter(reported_by=user)
    active = Assignment.objects.filter(status=ACTIVE).select_related("vehicle", "emergency")
    if user.role == Role.CITIZEN:
        active = active.filter(emergency__reported_by=user)
    blocked = RoadEdge.objects.select_related("from_node", "to_node").filter(
        Q(is_blocked=True) | ~Q(block_reason=""))
    return Response({
        "emergencies": EmergencySerializer(ems, many=True).data,
        "vehicles": VehicleBriefSerializer(Vehicle.objects.select_related("driver"), many=True).data,
        "routes": [planner.assignment_payload(a) for a in active],
        "blocked_roads": RoadEdgeSerializer(blocked, many=True).data,
    })


class AllocateView(APIView):
    """POST /api/allocate/ {dry_run?: bool} - run priority + DP + Dijkstra now."""

    permission_classes = [IsDispatcherOrAdmin]

    def post(self, request):
        dry = bool(request.data.get("dry_run", False))
        return Response(planner.run_allocation(Plan.Reason.MANUAL, request.user, dry_run=dry))


@api_view(["GET"])
@permission_classes([IsStaffRole])
def plan_current(request):
    """GET /api/plan/current/ - active assignments, routes, ETA, pending (FR-09)."""
    return Response(planner.plan_payload())


@api_view(["POST"])
@permission_classes([IsDispatcherOrAdmin])
def plan_recalculate(request):
    """POST /api/plan/recalculate/ {reason: NEW_EMERGENCY|VEHICLE_FREE|ROAD_BLOCKED|MANUAL} (FR-10)."""
    reason = str(request.data.get("reason", Plan.Reason.MANUAL)).upper()
    if reason not in Plan.Reason.values or reason == Plan.Reason.MANUAL_ASSIGN:
        raise BadRequest("reason must be one of NEW_EMERGENCY, VEHICLE_FREE, ROAD_BLOCKED, MANUAL.")
    rerouted = unreachable = []
    if reason == Plan.Reason.ROAD_BLOCKED:
        rerouted, unreachable = planner.reroute_active_assignments(request.user)
    payload = planner.run_allocation(reason, request.user)
    payload["rerouted_assignments"] = rerouted
    payload["unreachable_assignments"] = unreachable
    return Response(payload)


@api_view(["GET"])
@permission_classes([IsDispatcherOrAdmin])
def plan_history(request):
    """GET /api/plan/history/?limit=20 - previous plan runs with stats."""
    raw_limit = request.query_params.get("limit", 20)
    try:
        limit = min(max(1, int(raw_limit)), 200)
    except (ValueError, TypeError):
        raise BadRequest("limit must be a positive integer (max 200).")
    return Response([
        {"plan_id": p.id, "reason": p.reason, "created_at": p.created_at.isoformat(),
         "created_by": p.created_by.name if p.created_by else None, "summary": p.summary}
        for p in Plan.objects.select_related("created_by")[:limit]
    ])


@api_view(["POST"])
def route_view(request):
    """
    POST /api/route/ {vehicle_id, emergency_id}  or  {from_lat, from_lng, to_lat, to_lng}
    200 {path, route_coords, total_time, distance_km} | 404 {error: UNREACHABLE}  (FR-06/08)
    """
    s = RouteRequestSerializer(data=request.data)
    s.is_valid(raise_exception=True)
    d = s.validated_data
    if "vehicle_id" in d and "emergency_id" in d:
        v = get_object_or_404(Vehicle, pk=d["vehicle_id"])
        e = get_object_or_404(Emergency, pk=d["emergency_id"])
        if request.user.role == Role.CITIZEN and e.reported_by_id != request.user.id:
            raise Conflict("You can only view routes for your own reports.")
        a, b = (v.latitude, v.longitude), (e.latitude, e.longitude)
    else:
        a, b = (d["from_lat"], d["from_lng"]), (d["to_lat"], d["to_lng"])
    graph = get_graph()
    if graph.is_empty:
        raise Unreachable("Road network is empty. Run `python manage.py seed_demo` first.")
    r = graph.route(a, b)
    if r is None:
        raise Unreachable()
    return Response({"path": r.nodes, "edges": r.edges, "route_coords": r.coords,
                     "total_time": r.eta_minutes, "distance_km": r.distance_km})


# ---------------------------------------------------------------------------
# Assignments & driver missions
# ---------------------------------------------------------------------------


class AssignmentViewSet(viewsets.ReadOnlyModelViewSet):
    """
    GET  /api/assignments/?status=ACTIVE&vehicle=3
    POST /api/assignments/{id}/complete/   mark done, free vehicle
    """

    serializer_class = AssignmentSerializer
    permission_classes = [IsStaffRole]

    def get_queryset(self):
        qs = Assignment.objects.select_related("vehicle", "vehicle__driver", "emergency")
        if self.request.user.role == Role.DRIVER:
            qs = qs.filter(vehicle__driver=self.request.user)
        p = self.request.query_params
        if p.get("status"):
            qs = qs.filter(status=p["status"].upper())
        if p.get("vehicle"):
            qs = qs.filter(vehicle_id=p["vehicle"])
        if p.get("emergency"):
            qs = qs.filter(emergency_id=p["emergency"])
        return qs

    @action(detail=True, methods=["post"])
    def complete(self, request, pk=None):
        a = self.get_object()
        a = planner.complete_assignment(a.id, request.user)
        planner.maybe_auto_allocate(Plan.Reason.VEHICLE_FREE, request.user)
        a.vehicle.refresh_from_db()
        return Response({"assignment": AssignmentSerializer(a).data, "vehicle_status": a.vehicle.status})


def _mission_payload(a):
    em = Emergency.objects.prefetch_related(_active_assignments_prefetch()).get(pk=a.emergency_id)
    return {"assignment": AssignmentSerializer(a).data, "emergency": EmergencySerializer(em).data}


@api_view(["GET"])
@permission_classes([IsStaffRole])
def driver_mission(request):
    """GET /api/driver/mission/ - current active mission of the logged-in driver (or null)."""
    a = (Assignment.objects.filter(status=ACTIVE, vehicle__driver=request.user)
         .select_related("vehicle", "emergency").order_by("-assigned_at").first())
    vehicle = Vehicle.objects.filter(driver=request.user).first()
    return Response({
        "vehicle": VehicleBriefSerializer(vehicle).data if vehicle else None,
        "mission": _mission_payload(a) if a else None,
    })


@api_view(["GET"])
@permission_classes([IsStaffRole])
def driver_history(request):
    """GET /api/driver/history/ - completed missions of the logged-in driver."""
    qs = (Assignment.objects.filter(vehicle__driver=request.user)
          .exclude(status=ACTIVE).select_related("vehicle", "emergency")[:100])
    return Response(AssignmentSerializer(qs, many=True).data)


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------


def _notifications_for(user):
    return Notification.objects.filter(
        Q(target_user=user) | Q(target_user__isnull=True, target_role__in=["all", user.role])
    ).select_related("emergency")


@api_view(["GET"])
def notifications_list(request):
    """GET /api/notifications/?unread=true&limit=50 -> {unread_count, results}"""
    qs = _notifications_for(request.user)
    read_ids = set(NotificationRead.objects.filter(user=request.user).values_list("notification_id", flat=True))
    if _bool_param(request, "unread"):
        qs = qs.exclude(id__in=read_ids)
    raw_limit = request.query_params.get("limit", 50)
    try:
        limit = min(max(1, int(raw_limit)), 200)
    except (ValueError, TypeError):
        raise BadRequest("limit must be a positive integer (max 200).")
    unread = _notifications_for(request.user).exclude(id__in=read_ids).count()
    data = NotificationSerializer(qs[:limit], many=True, context={"read_ids": read_ids}).data
    return Response({"unread_count": unread, "results": data})


@api_view(["POST"])
def notification_read(request, pk):
    n = get_object_or_404(_notifications_for(request.user), pk=pk)
    NotificationRead.objects.get_or_create(notification=n, user=request.user)
    return Response({"ok": True})


@api_view(["POST"])
def notifications_read_all(request):
    read_ids = set(NotificationRead.objects.filter(user=request.user).values_list("notification_id", flat=True))
    new = [NotificationRead(notification_id=i, user=request.user)
           for i in _notifications_for(request.user).exclude(id__in=read_ids).values_list("id", flat=True)]
    NotificationRead.objects.bulk_create(new, ignore_conflicts=True)
    return Response({"ok": True, "marked": len(new)})


# ---------------------------------------------------------------------------
# Reports, audit, health
# ---------------------------------------------------------------------------


@api_view(["GET"])
@permission_classes([IsDispatcherOrAdmin])
def reports_summary(request):
    """GET /api/reports/summary/?days=30 - aggregate metrics for the admin reports screen."""
    raw_days = request.query_params.get("days", 30)
    try:
        days = min(max(1, int(raw_days)), 3650)
    except (ValueError, TypeError):
        raise BadRequest("days must be a positive integer.")
    since = timezone.now() - timedelta(days=days)
    ems = Emergency.objects.filter(created_at__gte=since)
    by_status = dict(ems.values_list("status").annotate(c=Count("id")).order_by())
    by_category = dict(ems.values_list("category").annotate(c=Count("id")).order_by())
    vehicles = dict(Vehicle.objects.values_list("status").annotate(c=Count("id")).order_by())
    total_vehicles = sum(vehicles.values())
    in_use = vehicles.get(VehicleStatus.BUSY, 0) + vehicles.get(VehicleStatus.EN_ROUTE, 0)
    asg = Assignment.objects.filter(assigned_at__gte=since)
    resolved = ems.filter(status=EmergencyStatus.RESOLVED, resolved_at__isnull=False)
    durations = [(e.resolved_at - e.created_at).total_seconds() / 60 for e in resolved.only("created_at", "resolved_at")]
    return Response({
        "period_days": days,
        "emergencies": {
            "total": ems.count(),
            "by_status": by_status,
            "by_category": by_category,
            "active": ems.filter(status__in=ACTIVE_EMERGENCY_STATUSES).count(),
            "avg_priority": round(ems.aggregate(a=Avg("priority_score"))["a"] or 0, 1),
            "people_affected": sum(ems.values_list("people_affected", flat=True)),
        },
        "vehicles": {
            "total": total_vehicles,
            "by_status": vehicles,
            "utilization_pct": round(100 * in_use / total_vehicles, 1) if total_vehicles else 0,
        },
        "assignments": {
            "total": asg.count(),
            "avg_eta_minutes": round(asg.aggregate(a=Avg("eta_minutes"))["a"] or 0, 1),
            "avg_resolution_minutes": round(sum(durations) / len(durations), 1) if durations else None,
        },
        "users": {r: User.objects.filter(role=r).count() for r in Role.values},
        "plans_run": Plan.objects.filter(created_at__gte=since).count(),
        "blocked_roads": RoadEdge.objects.filter(is_blocked=True).count(),
    })


class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    """GET /api/audit-logs/?event=PLAN_GENERATED (admin)"""

    serializer_class = AuditLogSerializer
    permission_classes = [IsAdmin]
    pagination_class = RoadPagination

    def get_queryset(self):
        qs = AuditLog.objects.select_related("actor")
        if self.request.query_params.get("event"):
            qs = qs.filter(event=self.request.query_params["event"])
        return qs


@api_view(["GET"])
@permission_classes([AllowAny])
def health(request):
    """GET /api/health/ - no auth; used by the app to check the server is reachable."""
    return Response({"status": "ok", "time": timezone.now().isoformat(),
                     "road_nodes": RoadNode.objects.count(), "vehicles": Vehicle.objects.count()})
