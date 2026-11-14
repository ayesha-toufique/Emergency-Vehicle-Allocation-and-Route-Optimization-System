from django.shortcuts import get_object_or_404
from rest_framework import generics, status
from rest_framework.authtoken.models import Token
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from dispatch.services.audit import audit
from dispatch.services.notify import notify

from .models import Role, User
from .permissions import IsAdmin
from .serializers import (
    ChangePasswordSerializer,
    LoginSerializer,
    RegisterSerializer,
    StaffCreateSerializer,
    UserSerializer,
)


def _auth_payload(user):
    token, _ = Token.objects.get_or_create(user=user)
    return {"token": token.key, "role": user.role, "user": UserSerializer(user).data}


class LoginView(APIView):
    """POST /api/auth/login/ {email, password} -> {token, role, user}"""

    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"

    def post(self, request):
        s = LoginSerializer(data=request.data, context={"request": request})
        s.is_valid(raise_exception=True)
        user = s.validated_data["user"]
        audit("USER_LOGIN", user, {"email": user.email})
        return Response(_auth_payload(user))


class RegisterView(APIView):
    """POST /api/auth/register/ - public citizen sign-up; logs the user in."""

    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"

    def post(self, request):
        s = RegisterSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        user = s.save()
        audit("USER_REGISTERED", user, {"email": user.email})
        return Response(_auth_payload(user), status=status.HTTP_201_CREATED)


class LogoutView(APIView):
    def post(self, request):
        Token.objects.filter(user=request.user).delete()
        return Response({"ok": True})


class MeView(generics.RetrieveUpdateAPIView):
    """GET/PATCH /api/auth/me/ - own profile (name, phone)."""

    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user


class ChangePasswordView(APIView):
    def post(self, request):
        s = ChangePasswordSerializer(data=request.data, context={"request": request})
        s.is_valid(raise_exception=True)
        request.user.set_password(s.validated_data["new_password"])
        request.user.save(update_fields=["password"])
        Token.objects.filter(user=request.user).delete()
        audit("PASSWORD_CHANGED", request.user)
        return Response(_auth_payload(request.user))


@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([ScopedRateThrottle])
def forgot_password(request):
    """
    POST /api/auth/forgot-password/ {email}
    Demo behaviour: always returns 200 (never reveals whether the email exists).
    No email is actually sent - configure Django EMAIL_* settings to add that.
    """
    email = str(request.data.get("email", "")).strip().lower()
    if not email:
        return Response({"error": "VALIDATION_ERROR", "message": "Email is required."}, status=400)
    if User.objects.filter(email=email).exists():
        audit("PASSWORD_RESET_REQUESTED", None, {"email": email})
    return Response({"ok": True, "message": "If this email is registered, reset instructions have been sent."})


forgot_password.throttle_scope = "auth"


class UserListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/users/?role=driver   (admin)  list users
    POST /api/users/               (admin)  create dispatcher/driver account
    """

    permission_classes = [IsAdmin]

    def get_serializer_class(self):
        return StaffCreateSerializer if self.request.method == "POST" else UserSerializer

    def get_queryset(self):
        qs = User.objects.all().prefetch_related("vehicles")
        role = self.request.query_params.get("role")
        if role:
            qs = qs.filter(role=role)
        return qs

    def create(self, request, *args, **kwargs):
        s = StaffCreateSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        user = s.save()
        audit("STAFF_CREATED", request.user, {"user_id": user.id, "role": user.role})
        notify(
            "New Staff Provisioned",
            f"Account for {user.name} ({user.role}) has been created by Administrator.",
            target_role=Role.ADMIN,
        )
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


class UserDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsAdmin]
    serializer_class = UserSerializer
    queryset = User.objects.all()


@api_view(["POST"])
@permission_classes([IsAdmin])
def toggle_user_active(request, pk):
    """POST /api/users/{id}/toggle-active/ - activate/deactivate an account."""
    user = get_object_or_404(User, pk=pk)
    if user == request.user:
        return Response({"error": "VALIDATION_ERROR", "message": "You cannot deactivate yourself."}, status=400)
    user.is_active = not user.is_active
    user.save(update_fields=["is_active"])
    if not user.is_active:
        Token.objects.filter(user=user).delete()
    audit("USER_ACTIVE_TOGGLED", request.user, {"user_id": user.id, "is_active": user.is_active})
    return Response(UserSerializer(user).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def user_counts(request):
    """GET /api/users/counts/ - number of users per role (dashboard cards)."""
    return Response({r: User.objects.filter(role=r).count() for r in Role.values})
