import { useState, useRef, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useSignIn, useSignUp, useClerk, useAuth } from "@clerk/clerk-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Loader2, Phone, ArrowLeft, KeyRound, Mail } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { authApi } from "@/lib/api";
import { sendPhoneOtp } from "@/lib/firebase";
import type { ConfirmationResult } from "firebase/auth";

type Step = "phone" | "otp" | "password" | "email" | "email_sent" | "email_verifying";

const REDIRECT_URL = `${window.location.origin}/login`;

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

  // Capture __clerk_ticket on first render — ClerkProvider strips it from
  // the URL during its own init, so by the time clerkLoaded=true it's gone.
  const [initialTicket] = useState(() =>
    new URLSearchParams(window.location.search).get("__clerk_ticket")
  );

  const { signIn, isLoaded: signInLoaded } = useSignIn();
  const { signUp, isLoaded: signUpLoaded } = useSignUp();
  const clerk = useClerk();
  const { getToken } = useAuth();

  const clerkLoaded = signInLoaded && signUpLoaded;

  // ── Handle magic link callback (/login?__clerk_ticket=xxx) ──
  useEffect(() => {
    if (!clerkLoaded || !signIn || !signUp) return;

    // Use the pre-captured ticket — ClerkProvider strips __clerk_ticket from
    // window.location.search during its init, before this effect fires.
    const ticket = initialTicket;
    if (!ticket) return;

    window.history.replaceState({}, "", window.location.pathname);
    setStep("email_verifying");

    const flow = sessionStorage.getItem("clerk_email_flow") ?? "signin";

    const finish = async (createdSessionId: string) => {
      await clerk.setActive({ session: createdSessionId });

      // Retry getting the token — session propagation can take a moment
      let clerkToken: string | null = null;
      for (let i = 0; i < 15; i++) {
        await new Promise((r) => setTimeout(r, 300));
        clerkToken = await getToken().catch(() => null);
        if (clerkToken) break;
      }

      if (!clerkToken) {
        throw new Error("Session token unavailable — please try again");
      }

      const response = await authApi.clerkLogin(clerkToken);
      if (response.success) {
        sessionStorage.removeItem("clerk_email_flow");
        toast({ title: "Welcome back!", description: `Signed in as ${response.data.user.username}` });
        navigate(response.data.user.role === "superadmin" ? "/superadmin" : "/dashboard");
      }
    };

    const onError = (err: any) => {
      const msg =
        err?.errors?.[0]?.longMessage ||
        err?.errors?.[0]?.message ||
        err?.response?.data?.detail ||
        err?.message ||
        "Something went wrong";
      toast({ title: "Sign-in failed", description: msg, variant: "destructive" });
      setStep("email");
      window.history.replaceState({}, "", window.location.pathname);
    };

    if (flow === "signup") {
      (signUp as any)
        .attemptEmailAddressVerification({ token: ticket })
        .then((result: any) => {
          if (result.status === "complete") return finish(result.createdSessionId);
          throw new Error("Sign-up incomplete");
        })
        .catch(onError);
    } else {
      (signIn as any)
        .attemptFirstFactor({ strategy: "email_link", ticket })
        .then((result: any) => {
          if (result.status === "complete") return finish(result.createdSessionId);
          throw new Error("Sign-in incomplete");
        })
        .catch(onError);
    }
  }, [clerkLoaded, initialTicket]); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Phone OTP ──
  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    try {
      const formattedPhone = phone.startsWith("+") ? phone : `+91${phone}`;
      confirmationRef.current = await sendPhoneOtp(formattedPhone, "recaptcha-container");
      toast({ title: "OTP Sent", description: `Code sent to ${formattedPhone}` });
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

  // ── Username / password ──
  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    try {
      const response = await authApi.login({ username, password });
      if (response.success) {
        toast({ title: "Welcome back!", description: `Logged in as ${response.data.user.username}` });
        navigate(response.data.user.role === "superadmin" ? "/superadmin" : "/dashboard");
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

  // ── Magic link — sign in, fall back to sign up if no Clerk account yet ──
  const handleSendMagicLink = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!clerkLoaded || !signIn || !signUp) return;
    setIsLoading(true);
    try {
      // Pre-flight: reject unknown emails before touching Clerk
      await authApi.checkEmail(magicEmail);

      // Try sign in first (returning user)
      await (signIn as any).create({
        strategy: "email_link",
        identifier: magicEmail,
        redirectUrl: REDIRECT_URL,
      });
      sessionStorage.setItem("clerk_email_flow", "signin");
      setStep("email_sent");
    } catch (signInErr: any) {
      const code = signInErr?.errors?.[0]?.code;
      if (code === "form_identifier_not_found") {
        // No Clerk account yet — create one (first-time login)
        try {
          await (signUp as any).create({ emailAddress: magicEmail });
          await (signUp as any).prepareEmailAddressVerification({
            strategy: "email_link",
            redirectUrl: REDIRECT_URL,
          });
          sessionStorage.setItem("clerk_email_flow", "signup");
          setStep("email_sent");
        } catch (signUpErr: any) {
          toast({
            title: "Failed to send link",
            description: signUpErr?.errors?.[0]?.longMessage || signUpErr?.errors?.[0]?.message || "Could not send link",
            variant: "destructive",
          });
        }
      } else {
        toast({
          title: "Failed to send link",
          description: signInErr?.errors?.[0]?.longMessage || signInErr?.errors?.[0]?.message || "Could not send link",
          variant: "destructive",
        });
      }
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

          {/* ── Phone ── */}
          {step === "phone" && (
            <div className="space-y-4">
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

          {/* ── OTP ── */}
          {step === "otp" && (
            <form onSubmit={handleVerifyOtp} className="space-y-4">
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
              <p className="text-center text-xs text-muted-foreground/60 mt-2">Contact your administrator if you need access</p>
            </form>
          )}

          {/* ── Email input ── */}
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
                  Click the link in your inbox to sign in. Expires in 10 minutes.
                </p>
              </div>
              <button type="button" onClick={() => setStep("email")}
                className="text-xs text-muted-foreground/60 hover:text-muted-foreground transition-colors">
                Use a different email
              </button>
            </div>
          )}

          {/* ── Verifying ── */}
          {step === "email_verifying" && (
            <div className="space-y-5 text-center py-4">
              <Loader2 className="h-10 w-10 animate-spin text-primary mx-auto" />
              <p className="text-sm text-muted-foreground">Verifying your magic link…</p>
            </div>
          )}

          {/* Superadmin link — only on phone step */}
          {step === "phone" && (
            <div className="mt-4 text-center">
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
