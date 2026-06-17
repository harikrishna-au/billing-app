import { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { useSignUp, useClerk } from "@clerk/clerk-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Loader2, UserPlus, CheckCircle, Mail, Phone, ArrowLeft } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { authApi } from "@/lib/api";

const SECRET_TOKEN = "lcaWo29pNaw";

type Step = "form" | "verify" | "done";

const Signup = () => {
  const { token } = useParams<{ token: string }>();
  const navigate = useNavigate();
  const { toast } = useToast();

  const [step, setStep] = useState<Step>("form");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const { signUp, isLoaded } = useSignUp();
  const clerk = useClerk();

  if (token !== SECRET_TOKEN) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-muted-foreground text-sm">404 — Page not found</p>
      </div>
    );
  }

  // Step 1: create Clerk account and send email OTP
  const handleSendCode = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!isLoaded || !signUp) return;
    setIsLoading(true);
    try {
      await (signUp as any).create({ emailAddress: email });
      await (signUp as any).prepareEmailAddressVerification({ strategy: "email_code" });
      setCode("");
      setStep("verify");
    } catch (err: any) {
      const msg = err?.errors?.[0]?.longMessage || err?.errors?.[0]?.message || "Could not send code";
      toast({ title: "Failed to send code", description: msg, variant: "destructive" });
    } finally {
      setIsLoading(false);
    }
  };

  // Step 2: verify OTP → create backend record → done
  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!isLoaded || !signUp) return;
    setIsLoading(true);
    try {
      const result = await (signUp as any).attemptEmailAddressVerification({ code });
      if (result.status !== "complete") throw new Error("Verification incomplete");

      // Activate Clerk session
      await clerk.setActive({ session: result.createdSessionId });

      // Get Clerk token and create backend account
      let clerkToken: string | null = null;
      for (let i = 0; i < 20; i++) {
        await new Promise((r) => setTimeout(r, 200));
        clerkToken = await clerk.session?.getToken().catch(() => null) ?? null;
        if (clerkToken) break;
      }
      if (!clerkToken) throw new Error("Could not get session token");

      await authApi.selfRegister({
        email,
        phone,
        token: SECRET_TOKEN,
        clerkToken,
      });

      setStep("done");
    } catch (err: any) {
      const msg = err?.response?.data?.detail || err?.errors?.[0]?.longMessage || err?.errors?.[0]?.message || err?.message || "Something went wrong";
      toast({ title: "Verification failed", description: msg, variant: "destructive" });
      setCode("");
    } finally {
      setIsLoading(false);
    }
  };

  if (step === "done") {
    return (
      <div className="login-container flex min-h-screen items-center justify-center p-4">
        <div className="w-full max-w-sm animate-scale-in">
          <div className="login-card px-8 py-10 text-center space-y-5">
            <div className="flex justify-center">
              <div className="flex h-14 w-14 items-center justify-center rounded-full bg-emerald-500/10">
                <CheckCircle className="h-7 w-7 text-emerald-500" />
              </div>
            </div>
            <div className="space-y-1.5">
              <p className="text-lg font-semibold text-foreground">Account created!</p>
              <p className="text-sm text-muted-foreground">
                You can now sign in with your email or phone number.
              </p>
            </div>
            <Button variant="glow" className="w-full" onClick={() => navigate("/login")}>
              Go to Login
            </Button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="login-container flex min-h-screen items-center justify-center p-4">
      <div id="clerk-captcha" />
      <div className="w-full max-w-sm animate-scale-in">
        <div className="login-card px-8 py-10">
          <div className="mb-8 flex flex-col items-center text-center">
            <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-xl bg-primary/10">
              <UserPlus className="h-6 w-6 text-primary" />
            </div>
            <h1 className="text-xl font-semibold text-foreground">Create Account</h1>
            <p className="mt-1.5 text-sm text-muted-foreground">
              {step === "form" ? "Set up your admin access" : `Enter the code sent to ${email}`}
            </p>
          </div>

          {/* ── Step 1: email + phone ── */}
          {step === "form" && (
            <form onSubmit={handleSendCode} className="space-y-4">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Email
                </Label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    type="email" value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    className="h-10 pl-9 bg-secondary/60 border-border/60 text-sm"
                    required autoFocus
                  />
                </div>
              </div>
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Phone Number
                </Label>
                <div className="relative">
                  <Phone className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    type="tel" value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="+91 98765 43210"
                    className="h-10 pl-9 bg-secondary/60 border-border/60 text-sm"
                    required
                  />
                </div>
                <p className="text-xs text-muted-foreground/60">Include country code or enter 10-digit number</p>
              </div>
              <Button type="submit" variant="glow" className="mt-2 w-full h-10 text-sm font-semibold"
                disabled={isLoading || !isLoaded}>
                {isLoading ? <><Loader2 className="h-4 w-4 animate-spin" /> Sending code…</> : "Send Verification Code"}
              </Button>
            </form>
          )}

          {/* ── Step 2: email OTP ── */}
          {step === "verify" && (
            <form onSubmit={handleVerify} className="space-y-4">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Verification Code
                </Label>
                <Input
                  type="text" inputMode="numeric" value={code}
                  onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
                  placeholder="Enter 6-digit code"
                  className="h-10 bg-secondary/60 border-border/60 text-sm tracking-widest text-center"
                  maxLength={6} required autoFocus
                />
                <p className="text-xs text-muted-foreground/60">Sent to {email}</p>
              </div>
              <Button type="submit" variant="glow" className="mt-2 w-full h-10 text-sm font-semibold"
                disabled={isLoading || code.length < 6}>
                {isLoading ? <><Loader2 className="h-4 w-4 animate-spin" /> Verifying…</> : "Verify & Create Account"}
              </Button>
              <button type="button" onClick={() => { setStep("form"); setCode(""); }}
                className="flex items-center gap-1.5 text-xs text-muted-foreground/60 hover:text-muted-foreground mx-auto transition-colors">
                <ArrowLeft className="h-3 w-3" /> Back
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
};

export default Signup;
