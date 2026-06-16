import { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Loader2, UserPlus, CheckCircle } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { authApi } from "@/lib/api";

const SECRET_TOKEN = "lcaWo29pNaw";

const Signup = () => {
  const { token } = useParams<{ token: string }>();
  const navigate = useNavigate();
  const { toast } = useToast();

  const [form, setForm] = useState({ username: "", email: "", phone: "", password: "", confirm: "" });
  const [isLoading, setIsLoading] = useState(false);
  const [done, setDone] = useState(false);

  // Wrong URL — show nothing (404-like)
  if (token !== SECRET_TOKEN) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-muted-foreground text-sm">404 — Page not found</p>
      </div>
    );
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (form.password !== form.confirm) {
      toast({ title: "Passwords don't match", variant: "destructive" });
      return;
    }
    setIsLoading(true);
    try {
      await authApi.selfRegister({
        username: form.username,
        email: form.email,
        phone: form.phone || undefined,
        password: form.password,
        token: SECRET_TOKEN,
      });
      setDone(true);
    } catch (err: any) {
      toast({
        title: "Registration failed",
        description: err?.response?.data?.detail || "Something went wrong",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  if (done) {
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
      <div className="w-full max-w-sm animate-scale-in">
        <div className="login-card px-8 py-10">
          <div className="mb-8 flex flex-col items-center text-center">
            <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-xl bg-primary/10">
              <UserPlus className="h-6 w-6 text-primary" />
            </div>
            <h1 className="text-xl font-semibold text-foreground">Create Account</h1>
            <p className="mt-1.5 text-sm text-muted-foreground">Set up your admin access</p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            {[
              { label: "Username", key: "username", type: "text", placeholder: "e.g. john_admin" },
              { label: "Email", key: "email", type: "email", placeholder: "you@example.com" },
              { label: "Phone (optional)", key: "phone", type: "tel", placeholder: "+91 98765 43210" },
              { label: "Password", key: "password", type: "password", placeholder: "Min 6 characters" },
              { label: "Confirm Password", key: "confirm", type: "password", placeholder: "Re-enter password" },
            ].map(({ label, key, type, placeholder }) => (
              <div key={key} className="space-y-1.5">
                <Label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  {label}
                </Label>
                <Input
                  type={type}
                  value={form[key as keyof typeof form]}
                  onChange={(e) => setForm({ ...form, [key]: e.target.value })}
                  placeholder={placeholder}
                  className="h-10 bg-secondary/60 border-border/60 text-sm"
                  required={key !== "phone"}
                  minLength={key === "password" || key === "confirm" ? 6 : undefined}
                  autoFocus={key === "username"}
                />
              </div>
            ))}

            <Button type="submit" variant="glow" className="mt-2 w-full h-10 text-sm font-semibold" disabled={isLoading}>
              {isLoading ? <><Loader2 className="h-4 w-4 animate-spin" /> Creating account…</> : "Create Account"}
            </Button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default Signup;
