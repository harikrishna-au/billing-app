import httpx
import base64
import time
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional

from app.core.config import settings
from app.dependencies import get_current_user

router = APIRouter()


class CreateOrderRequest(BaseModel):
    amount: int          # in paise (₹1 = 100 paise)
    currency: str = "INR"
    receipt: Optional[str] = None
    notes: Optional[dict] = None


@router.post("/razorpay/create-order")
async def create_razorpay_order(
    body: CreateOrderRequest,
    current_user=Depends(get_current_user),
):
    if not settings.RAZORPAY_KEY_ID or not settings.RAZORPAY_KEY_SECRET:
        raise HTTPException(status_code=500, detail="Razorpay not configured")

    if body.amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive (in paise)")

    credentials = base64.b64encode(
        f"{settings.RAZORPAY_KEY_ID}:{settings.RAZORPAY_KEY_SECRET}".encode()
    ).decode()

    payload = {
        "amount": body.amount,
        "currency": body.currency,
        "receipt": body.receipt or f"rcpt_{int(time.time())}",
    }
    if body.notes:
        payload["notes"] = body.notes

    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.razorpay.com/v1/orders",
            json=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Basic {credentials}",
            },
            timeout=15.0,
        )

    if response.status_code != 200:
        detail = response.json().get("error", {}).get("description", "Failed to create order")
        raise HTTPException(status_code=response.status_code, detail=detail)

    return response.json()
