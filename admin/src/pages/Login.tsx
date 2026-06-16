import { useState, useRef, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useSignIn, useClerk } from "@clerk/clerk-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Loader2, Phone, ArrowLeft, KeyRound, Mail, CheckCircle } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { authApi } from "@/lib/api";
import { sendPhoneOtp } from "@/lib/firebase";
import type { ConfirmationResult } from "firebase/auth";

type Step = "phone" | "otp" | "password" | "email" | "email_sent" | "email_verifying";

const Login = () => {
  const [step, setStep] = useState<Step>("phone");
  const [phone, setPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [magicEmail, setMagicEmail] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const confirmationRef = useRef<ConfirmationResult | null>(null);
  const navigate = useNavigate();
  const { toast } = useToast();

  const { signIn, isLoaded: clerkLoaded } = useSignIn();
  const clerk = useClerk();

  // Handle Clerk magic link callback — runs when user clicks the link in email
  useEffect(() => {
    if (!clerkLoaded || !signIn) return;

    const params = new URLSearchParams(window.location.search);
    const ticket = params.get("__clerk_ticket");
    if (!ticket) return;

    setStep("email_verifying");

    signIn
      .attemptFirstFactor({ strategy: "email_link", ticket } as any)
      .then(async (result) => {
        if (result.status === "complete") {
          await clerk.setActive({ session: result.createdSessionId });
          // Small tick for Clerk to update session object
          await new Promise((r) => setTimeout(r, 200));
          const clerkToken = await clerk.session?.getToken();
          if (!clerkToken) throw new Error("Could not get Clerk token");
          const response = await authApi.clerkLogin(clerkToken);
          if (response.success) {
            toast({ title: "Welcome back!", description: `Signed in as ${response.data.user.username}` });
            const role = response.data.user.role;
            navigate(role === "superadmin" ? "/superadmin" : "/dashboard");
          }
        } else {
          throw new Error("Sign-in incomplete");
        }
      })
      .catch((err: any) => {
        toast({
          title: "Link expired or invalid",
          description: err?.errors?.[0]?.message || "Request a new magic link",
          variant: "destructive",
        });
        setStep("email");
        // Clean up URL
        window.history.replaceState({}, "", window.location.pathname);
      });
  }, [clerkLoaded]); // eslint-disable-line react-hooks/exhaustive-deps

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
      toast({ title: "Failed to send OTP", description: error.message || "Could not send code", variant: "destructive" });
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
        toast({ title: "Welcome back!", description: `Logged in as ${response.data.user.username}` });
        navigate("/dashboard");
      }
    } catch (error: any) {
      toast({
        title: "Verification failed",
        description: error.response?.data?.detail || error.message || "Wrong OTP",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    try {
      const response = await authApi.login({ username, password });
      if (response.success) {
        toast({ title: "Welcome back!", description: `Logged in as ${response.data.user.username}` });
        const role = response.data.user.role;
        navigate(role === "superadmin" ? "/superadmin" : "/dashboard");
      }
    } catch (error: any) {
      toast({
        title: "Login failed",
        description: error.response?.data?.detail || "Invalid username or password",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleSendMagicLink = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!clerkLoaded || !signIn) return;
    setIsLoading(true);
    try {
      await (signIn as any).create({
        strategy: "email_link",
        identifier: magicEmail,
        redirectUrl: `${window.location.origin}/login`,
      });
      setStep("email_sent");
    } catch (err: any) {
      toast({
        title: "Failed to send magic link",
        description: err?.errors?.[0]?.longMessage || err?.errors?.[0]?.message || "Could not send link",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const subtitle: Record<Step, string> = {
    phone: "Sign in with your phone number",
    otp: "Enter the OTP sent to your phone",
    password: "Sign in with your credentials",
    email: "Sign in with your email",
    email_sent: "Check your inbox",
    email_verifying: "Verifying your link…",
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

          {/* ── Phone step ── */}
          {step === "phone" && (
            <form onSubmit={handleSendOtp} className="space-y-4">
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
          )}

          {/* ── OTP step ── */}
          {step === "otp" && (
            <form onSubmit={handleVerifyOtp} className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="otp" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Verification Code
                </Label>
                <Input
                  id="otp" type="text" inputMode="numeric"
                  value={otp}
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

          {/* ── Username / password step ── */}
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
                <Label htmlFor="password" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Password</Label>
                <Input id="password" type="password" value={password}
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
                <ArrowLeft className="h-3 w-3" /> Back to phone login
              </button>
            </form>
          )}

          {/* ── Email input step ── */}
          {step === "email" && (
            <form onSubmit={handleSendMagicLink} className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="magic-email" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Email Address
                </Label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    id="magic-email" type="email" value={magicEmail}
                    onChange={(e) => setMagicEmail(e.target.value)}
                    placeholder="you@example.com"
                    className="h-10 pl-9 bg-secondary/60 border-border/60 text-sm"
                    required autoFocus
                  />
                </div>
                <p className="text-xs text-muted-foreground/60">We'll send a magic link — no password needed</p>
              </div>
              <Button type="submit" variant="glow" className="mt-2 w-full h-10 text-sm font-semibold"
                disabled={isLoading || !clerkLoaded}>
                {isLoading ? <><Loader2 className="h-4 w-4 animate-spin" /> Sending link…</> : "Send Magic Link"}
              </Button>
              <button type="button" onClick={() => setStep("phone")}
                className="flex items-center gap-1.5 text-xs text-muted-foreground/60 hover:text-muted-foreground mx-auto transition-colors">
                <ArrowLeft className="h-3 w-3" /> Back to phone login
              </button>
            </form>
          )}

          {/* ── Magic link sent ── */}
          {step === "email_sent" && (
            <div className="space-y-5 text-center">
              <div className="flex justify-center">
                <div className="flex h-14 w-14 items-center justify-center rounded-full bg-primary/10">
                  <Mail className="h-7 w-7 text-primary" />
                </div>
              </div>
              <div className="space-y-1.5">
                <p className="text-sm font-medium text-foreground">Link sent to</p>
                <p className="text-sm font-semibold text-primary">{magicEmail}</p>
                <p className="text-xs text-muted-foreground mt-2">
                  Click the link in your inbox to sign in. This link expires in 10 minutes.
                </p>
              </div>
              <button type="button" onClick={() => setStep("email")}
                className="text-xs text-muted-foreground/60 hover:text-muted-foreground transition-colors">
                Use a different email
              </button>
            </div>
          )}

          {/* ── Verifying magic link ── */}
          {step === "email_verifying" && (
            <div className="space-y-5 text-center py-4">
              <Loader2 className="h-10 w-10 animate-spin text-primary mx-auto" />
              <p className="text-sm text-muted-foreground">Verifying your magic link…</p>
            </div>
          )}

          {/* Footer links (hidden while verifying) */}
          {step !== "email_verifying" && step !== "email_sent" && (
            <div className="mt-6 flex flex-col items-center gap-2">
              {step === "phone" && (
                <>
                  <button type="button" onClick={() => setStep("email")}
                    className="inline-flex items-center gap-1 text-xs text-muted-foreground/60 hover:text-muted-foreground transition-colors">
                    <Mail className="h-3 w-3" /> Sign in with email
                  </button>
                  <button type="button" onClick={() => setStep("password")}
                    className="inline-flex items-center gap-1 text-xs text-muted-foreground/60 hover:text-muted-foreground transition-colors">
                    <KeyRound className="h-3 w-3" /> Sign in with username
                  </button>
                </>
              )}
              {step === "email" && (
                <button type="button" onClick={() => setStep("phone")}
                  className="inline-flex items-center gap-1 text-xs text-muted-foreground/60 hover:text-muted-foreground transition-colors">
                  <Phone className="h-3 w-3" /> Use phone OTP instead
                </button>
              )}
              {step === "password" && (
                <p className="text-xs text-muted-foreground/60">Contact your administrator if you need access</p>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Login;
