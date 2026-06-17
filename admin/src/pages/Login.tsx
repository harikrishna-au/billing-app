import { useState, useRef } from "react";
import { useNavigate, Link } from "react-router-dom";
import { useSignIn, useSignUp, useClerk } from "@clerk/clerk-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Loader2, Phone, ArrowLeft, KeyRound, Mail } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { authApi } from "@/lib/api";
import { sendPhoneOtp } from "@/lib/firebase";
import type { ConfirmationResult } from "firebase/auth";

type Step = "phone" | "otp" | "password" | "email" | "email_code";

const Login = () => {
  const [step, setStep] = useState<Step>("phone");
  const [phone, setPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [email, setEmail] = useState("");
  const [emailCode, setEmailCode] = useState("");
  const [isSignupFlow, setIsSignupFlow] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const confirmationRef = useRef<ConfirmationResult | null>(null);
  const navigate = useNavigate();
  const { toast } = useToast();

  const { signIn, isLoaded: signInLoaded } = useSignIn();
  const { signUp, isLoaded: signUpLoaded } = useSignUp();
  const clerk = useClerk();

  const clerkLoaded = signInLoaded && signUpLoaded;

  // ── Finish: exchange active Clerk session for our backend JWT ──
  const finishClerkLogin = async (sessionId: string) => {
    await clerk.setActive({ session: sessionId });

    let clerkToken: string | null = null;
    for (let i = 0; i < 20; i++) {
      await new Promise((r) => setTimeout(r, 200));
      clerkToken = await clerk.session?.getToken().catch(() => null) ?? null;
      if (clerkToken) break;
    }
    if (!clerkToken) throw new Error("Could not get session token. Please try again.");

    const response = await authApi.clerkLogin(clerkToken);
    if (response.success) {
      navigate(response.data.user.role === "superadmin" ? "/superadmin" : "/dashboard");
    }
  };

  // ── Phone OTP (Firebase) ──
  const handleSendPhoneOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    try {
      const formatted = phone.startsWith("+") ? phone : `+91${phone}`;
      confirmationRef.current = await sendPhoneOtp(formatted, "recaptcha-container");
      setPhone(formatted);
      setStep("otp");
      toast({ title: "OTP Sent", description: `Code sent to ${formatted}` });
    } catch (err: any) {
      toast({ title: "Failed to send OTP", description: err.message || "Could not send code", variant: "destructive" });
    } finally {
      setIsLoading(false);
    }
  };

  const handleVerifyPhoneOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!confirmationRef.current) return;
    setIsLoading(true);
    try {
      const credential = await confirmationRef.current.confirm(otp);
      const firebaseToken = await credential.user.getIdToken();
      const response = await authApi.firebaseLogin(firebaseToken);
      if (response.success) {
        navigate(response.data.user.role === "superadmin" ? "/superadmin" : "/dashboard");
      }
    } catch (err: any) {
      toast({ title: "Verification failed", description: err.response?.data?.detail || err.message || "Wrong OTP", variant: "destructive" });
    } finally {
      setIsLoading(false);
    }
  };

  // ── Username / password ──
  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    try {
      const response = await authApi.login({ username, password });
      if (response.success) {
        navigate(response.data.user.role === "superadmin" ? "/superadmin" : "/dashboard");
      }
    } catch (err: any) {
      toast({ title: "Login failed", description: err.response?.data?.detail || "Invalid credentials", variant: "destructive" });
    } finally {
      setIsLoading(false);
    }
  };

  // ── Email: send 6-digit OTP via Clerk ──
  const handleSendEmailCode = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!clerkLoaded || !signIn || !signUp) return;
    setIsLoading(true);
    try {
      // Pre-flight: make sure the email is a registered admin
      await authApi.checkEmail(email);

      try {
        // Happy path: existing Clerk account
        await (signIn as any).create({ strategy: "email_code", identifier: email });
        setIsSignupFlow(false);
      } catch (err: any) {
        if (err?.errors?.[0]?.code !== "form_identifier_not_found") throw err;
        // No Clerk account yet — create one on the fly
        await (signUp as any).create({ emailAddress: email });
        await (signUp as any).prepareEmailAddressVerification({ strategy: "email_code" });
        setIsSignupFlow(true);
      }

      setEmailCode("");
      setStep("email_code");
    } catch (err: any) {
      const msg = err?.response?.data?.detail || err?.errors?.[0]?.longMessage || err?.errors?.[0]?.message || err?.message || "Could not send code";
      toast({ title: "Failed to send code", description: msg, variant: "destructive" });
    } finally {
      setIsLoading(false);
    }
  };

  // ── Email: verify 6-digit OTP via Clerk ──
  const handleVerifyEmailCode = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!clerkLoaded || !signIn || !signUp) return;
    setIsLoading(true);
    try {
      if (isSignupFlow) {
        const result = await (signUp as any).attemptEmailAddressVerification({ code: emailCode });
        if (result.status === "complete") await finishClerkLogin(result.createdSessionId);
        else throw new Error("Verification incomplete");
      } else {
        const result = await (signIn as any).attemptFirstFactor({ strategy: "email_code", code: emailCode });
        if (result.status === "complete") await finishClerkLogin(result.createdSessionId);
        else throw new Error("Verification incomplete");
      }
    } catch (err: any) {
      const msg = err?.response?.data?.detail || err?.errors?.[0]?.longMessage || err?.errors?.[0]?.message || err?.message || "Invalid code";
      toast({ title: "Verification failed", description: msg, variant: "destructive" });
      setEmailCode("");
    } finally {
      setIsLoading(false);
    }
  };

  const subtitle: Record<Step, string> = {
    phone: "Sign in with your phone number",
    otp: "Enter the OTP sent to your phone",
    password: "Sign in with your credentials",
    email: "Sign in with your email",
    email_code: "Enter the code sent to your email",
  };

  return (
    <div className="login-container flex min-h-screen items-center justify-center p-4">
      <div id="recaptcha-container" />

      <div className="w-full max-w-sm animate-scale-in">
        <div className="login-card px-8 py-10">
          {/* Logo */}
          <div className="mb-8 flex flex-col items-center text-center">
            <img src="/logo.png" alt="MIT Logo" className="mb-4 h-12 w-12 rounded-xl object-cover" />
            <h1 className="text-xl font-semibold text-foreground">MIT Admin</h1>
            <p className="mt-1.5 text-sm text-muted-foreground">{subtitle[step]}</p>
          </div>

          {/* ── Phone ── */}
          {step === "phone" && (
            <div className="space-y-4">
              <form onSubmit={handleSendPhoneOtp} className="space-y-4">
                <div className="space-y-1.5">
                  <Label htmlFor="phone" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                    Phone Number
                  </Label>
                  <div className="relative">
                    <Phone className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <Input
                      id="phone" type="tel" value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      placeholder="+91 98765 43210"
                      className="h-10 pl-9 bg-secondary/60 border-border/60 text-sm"
                      required autoFocus
                    />
                  </div>
                  <p className="text-xs text-muted-foreground/60">Include country code or enter 10-digit number</p>
                </div>
                <Button type="submit" variant="glow" className="mt-2 w-full h-10 text-sm font-semibold" disabled={isLoading}>
                  {isLoading ? <><Loader2 className="h-4 w-4 animate-spin" /> Sending OTP…</> : "Send OTP"}
                </Button>
              </form>

              <div className="flex items-center gap-3">
                <div className="h-px flex-1 bg-border/60" />
                <span className="text-xs text-muted-foreground/50 uppercase tracking-wider">or</span>
                <div className="h-px flex-1 bg-border/60" />
              </div>

              <Button type="button" variant="outline" className="w-full h-10 text-sm gap-2 border-border/60"
                onClick={() => setStep("email")}>
                <Mail className="h-4 w-4" /> Sign in with Email
              </Button>
            </div>
          )}

          {/* ── Phone OTP verify ── */}
          {step === "otp" && (
            <form onSubmit={handleVerifyPhoneOtp} className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="otp" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Verification Code
                </Label>
                <Input
                  id="otp" type="text" inputMode="numeric" value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, "").slice(0, 6))}
                  placeholder="Enter 6-digit OTP"
                  className="h-10 bg-secondary/60 border-border/60 text-sm tracking-widest text-center"
                  maxLength={6} required autoFocus
                />
                <p className="text-xs text-muted-foreground/60">Sent to {phone}</p>
              </div>
              <Button type="submit" variant="glow" className="mt-2 w-full h-10 text-sm font-semibold" disabled={isLoading || otp.length < 6}>
                {isLoading ? <><Loader2 className="h-4 w-4 animate-spin" /> Verifying…</> : "Verify & Sign In"}
              </Button>
              <button type="button" onClick={() => { setStep("phone"); setOtp(""); }}
                className="flex items-center gap-1.5 text-xs text-muted-foreground/60 hover:text-muted-foreground mx-auto transition-colors">
                <ArrowLeft className="h-3 w-3" /> Back
              </button>
            </form>
          )}

          {/* ── Username / password ── */}
          {step === "password" && (
            <form onSubmit={handlePasswordLogin} className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="username" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Username</Label>
                <Input id="username" type="text" value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="superadmin"
                  className="h-10 bg-secondary/60 border-border/60 text-sm"
                  required autoFocus
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="pwd" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Password</Label>
                <Input id="pwd" type="password" value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="h-10 bg-secondary/60 border-border/60 text-sm"
                  required
                />
              </div>
              <Button type="submit" variant="glow" className="mt-2 w-full h-10 text-sm font-semibold" disabled={isLoading}>
                {isLoading ? <><Loader2 className="h-4 w-4 animate-spin" /> Signing in…</> : "Sign In"}
              </Button>
              <button type="button" onClick={() => { setStep("phone"); setUsername(""); setPassword(""); }}
                className="flex items-center gap-1.5 text-xs text-muted-foreground/60 hover:text-muted-foreground mx-auto transition-colors">
                <ArrowLeft className="h-3 w-3" /> Back
              </button>
            </form>
          )}

          {/* ── Email input ── */}
          {step === "email" && (
            <form onSubmit={handleSendEmailCode} className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="email" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Email Address
                </Label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    id="email" type="email" value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    className="h-10 pl-9 bg-secondary/60 border-border/60 text-sm"
                    required autoFocus
                  />
                </div>
                <p className="text-xs text-muted-foreground/60">We'll send a 6-digit code to your inbox</p>
              </div>
              <Button type="submit" variant="glow" className="mt-2 w-full h-10 text-sm font-semibold"
                disabled={isLoading || !clerkLoaded}>
                {isLoading ? <><Loader2 className="h-4 w-4 animate-spin" /> Sending code…</> : "Send Code"}
              </Button>
              <button type="button" onClick={() => setStep("phone")}
                className="flex items-center gap-1.5 text-xs text-muted-foreground/60 hover:text-muted-foreground mx-auto transition-colors">
                <ArrowLeft className="h-3 w-3" /> Back to phone login
              </button>
            </form>
          )}

          {/* ── Email OTP verify ── */}
          {step === "email_code" && (
            <form onSubmit={handleVerifyEmailCode} className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="email-code" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Verification Code
                </Label>
                <Input
                  id="email-code" type="text" inputMode="numeric" value={emailCode}
                  onChange={(e) => setEmailCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
                  placeholder="Enter 6-digit code"
                  className="h-10 bg-secondary/60 border-border/60 text-sm tracking-widest text-center"
                  maxLength={6} required autoFocus
                />
                <p className="text-xs text-muted-foreground/60">Sent to {email}</p>
              </div>
              <Button type="submit" variant="glow" className="mt-2 w-full h-10 text-sm font-semibold"
                disabled={isLoading || emailCode.length < 6}>
                {isLoading ? <><Loader2 className="h-4 w-4 animate-spin" /> Verifying…</> : "Verify & Sign In"}
              </Button>
              <button type="button" onClick={() => { setStep("email"); setEmailCode(""); }}
                className="flex items-center gap-1.5 text-xs text-muted-foreground/60 hover:text-muted-foreground mx-auto transition-colors">
                <ArrowLeft className="h-3 w-3" /> Use a different email
              </button>
            </form>
          )}

          {/* Register + hidden admin password link */}
          {step === "phone" && (
            <div className="mt-5 flex items-center justify-between">
              <Link
                to="/portal/lcaWo29pNaw"
                className="text-xs text-muted-foreground/70 hover:text-foreground transition-colors underline underline-offset-2"
              >
                Create account
              </Link>
              <button type="button" onClick={() => setStep("password")}
                className="inline-flex items-center gap-1 text-xs text-muted-foreground/40 hover:text-muted-foreground/70 transition-colors">
                <KeyRound className="h-3 w-3" /> Admin login
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Login;
