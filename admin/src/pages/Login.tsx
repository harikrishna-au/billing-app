import { useState, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Loader2, Phone, ArrowLeft } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { authApi } from "@/lib/api";
import { sendPhoneOtp } from "@/lib/firebase";
import type { ConfirmationResult } from "firebase/auth";

type Step = "phone" | "otp";

const Login = () => {
  const [step, setStep] = useState<Step>("phone");
  const [phone, setPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const confirmationRef = useRef<ConfirmationResult | null>(null);
  const navigate = useNavigate();
  const { toast } = useToast();

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      const formattedPhone = phone.startsWith("+") ? phone : `+91${phone}`;
      confirmationRef.current = await sendPhoneOtp(formattedPhone, "recaptcha-container");
      toast({ title: "OTP Sent", description: `Verification code sent to ${formattedPhone}` });
      setPhone(formattedPhone);
      setStep("otp");
    } catch (error: any) {
      toast({
        title: "Failed to send OTP",
        description: error.message || "Could not send verification code",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!confirmationRef.current) return;
    setIsLoading(true);

    try {
      const credential = await confirmationRef.current.confirm(otp);
      const firebaseIdToken = await credential.user.getIdToken();

      const response = await authApi.firebaseLogin(firebaseIdToken);

      if (response.success) {
        toast({
          title: "Welcome back!",
          description: `Logged in as ${response.data.user.username}`,
        });
        navigate("/dashboard");
      }
    } catch (error: any) {
      const message =
        error.response?.data?.detail ||
        error.message ||
        "Verification failed";

      toast({
        title: "Verification failed",
        description: message,
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="login-container flex min-h-screen items-center justify-center p-4">
      {/* Invisible reCAPTCHA mount point */}
      <div id="recaptcha-container" />

      <div className="w-full max-w-sm animate-scale-in">
        <div className="login-card px-8 py-10">
          {/* Logo */}
          <div className="mb-8 flex flex-col items-center text-center">
            <img src="/logo.png" alt="MIT Logo" className="mb-4 h-12 w-12 rounded-xl object-cover" />
            <h1 className="text-xl font-semibold text-foreground">MIT Admin</h1>
            <p className="mt-1.5 text-sm text-muted-foreground">
              {step === "phone"
                ? "Sign in with your phone number"
                : "Enter the OTP sent to your phone"}
            </p>
          </div>

          {/* Step 1: Phone */}
          {step === "phone" && (
            <form onSubmit={handleSendOtp} className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="phone" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Phone Number
                </Label>
                <div className="relative">
                  <Phone className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    id="phone"
                    type="tel"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="+91 98765 43210"
                    className="h-10 pl-9 bg-secondary/60 border-border/60 text-sm placeholder:text-muted-foreground/50 focus:border-primary/50 focus:ring-1 focus:ring-primary/20"
                    required
                    autoFocus
                  />
                </div>
                <p className="text-xs text-muted-foreground/60">
                  Include country code or enter 10-digit number
                </p>
              </div>

              <Button
                type="submit"
                variant="glow"
                className="mt-2 w-full h-10 text-sm font-semibold"
                disabled={isLoading}
              >
                {isLoading ? (
                  <><Loader2 className="h-4 w-4 animate-spin" /> Sending OTP...</>
                ) : (
                  "Send OTP"
                )}
              </Button>
            </form>
          )}

          {/* Step 2: OTP */}
          {step === "otp" && (
            <form onSubmit={handleVerifyOtp} className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="otp" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Verification Code
                </Label>
                <Input
                  id="otp"
                  type="text"
                  inputMode="numeric"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, "").slice(0, 6))}
                  placeholder="Enter 6-digit OTP"
                  className="h-10 bg-secondary/60 border-border/60 text-sm tracking-widest text-center placeholder:text-muted-foreground/50 focus:border-primary/50 focus:ring-1 focus:ring-primary/20"
                  maxLength={6}
                  required
                  autoFocus
                />
                <p className="text-xs text-muted-foreground/60">Sent to {phone}</p>
              </div>

              <Button
                type="submit"
                variant="glow"
                className="mt-2 w-full h-10 text-sm font-semibold"
                disabled={isLoading || otp.length < 6}
              >
                {isLoading ? (
                  <><Loader2 className="h-4 w-4 animate-spin" /> Verifying...</>
                ) : (
                  "Verify & Sign In"
                )}
              </Button>

              <button
                type="button"
                onClick={() => { setStep("phone"); setOtp(""); }}
                className="flex items-center gap-1.5 text-xs text-muted-foreground/60 hover:text-muted-foreground mx-auto transition-colors"
              >
                <ArrowLeft className="h-3 w-3" /> Back
              </button>
            </form>
          )}

          <p className="mt-6 text-center text-xs text-muted-foreground/60">
            Contact your administrator if you need access
          </p>
        </div>
      </div>
    </div>
  );
};

export default Login;
