from fastapi import APIRouter

from app.api.v1 import auth, dashboard, machines, services, payments, logs, analytics, sync, alerts

router = APIRouter()

router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
router.include_router(dashboard.router, prefix="/dashboard", tags=["Dashboard"])
router.include_router(machines.router, prefix="/machines", tags=["Machines"])
router.include_router(services.router, tags=["Services"])

router.include_router(payments.router, tags=["Payments"])
router.include_router(logs.router, tags=["Logs"])
router.include_router(analytics.router, prefix="/analytics", tags=["Analytics"])
router.include_router(sync.router, prefix="/sync", tags=["Sync"])
router.include_router(alerts.router, prefix="/alerts", tags=["Alerts"])

api_router = router
__all__ = ["api_router"]

