import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import SuperAdminLayout from "@/components/layout/SuperAdminLayout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription,
} from "@/components/ui/dialog";
import { useToast } from "@/hooks/use-toast";
import { superadminApi, type AdminSummary } from "@/lib/api/superadmin";
import { Plus, Eye, ShieldCheck, ShieldOff, Monitor, Loader2 } from "lucide-react";

function fmt(iso: string | null) {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

const AdminsPage = () => {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [selected, setSelected] = useState<AdminSummary | null>(null);
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [form, setForm] = useState({ username: "", email: "", phone: "", password: "" });

  const { data: admins = [], isLoading } = useQuery({
    queryKey: ["sa-admins"],
    queryFn: superadminApi.listAdmins,
    refetchInterval: 30_000,
  });

  const { data: detail, isLoading: detailLoading } = useQuery({
    queryKey: ["sa-admin-detail", selected?.id],
    queryFn: () => superadminApi.getAdmin(selected!.id),
    enabled: !!selected,
  });

  const createMutation = useMutation({
    mutationFn: superadminApi.createAdmin,
    onSuccess: (result) => {
      qc.invalidateQueries({ queryKey: ["sa-admins"] });
      if (result.clerk_ready) {
        toast({ title: "Admin created", description: "Login invite sent via Clerk email OTP." });
      } else {
        toast({
          title: "Admin created — Clerk invite failed",
          description: "Account exists but the Clerk email invite didn't send. The admin can still log in once Clerk is set up.",
          variant: "destructive",
        });
      }
      setIsCreateOpen(false);
      setForm({ username: "", email: "", phone: "", password: "" });
    },
    onError: (e: any) =>
      toast({ title: "Error", description: e?.response?.data?.detail || "Failed", variant: "destructive" }),
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) =>
      superadminApi.toggleAdminStatus(id, active),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["sa-admins"] });
      toast({ title: "Status updated" });
    },
    onError: () => toast({ title: "Error", description: "Failed to update", variant: "destructive" }),
  });

  return (
    <SuperAdminLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between animate-fade-in">
          <div>
            <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-1">Superadmin</p>
            <h1 className="text-2xl font-semibold text-foreground">Admin Accounts</h1>
            <p className="text-sm text-muted-foreground">Manage all admin accounts and their access</p>
          </div>
          <Button variant="glow" onClick={() => setIsCreateOpen(true)}>
            <Plus className="h-4 w-4 mr-2" /> New Admin
          </Button>
        </div>

        <div className="stat-card animate-slide-up">
          {isLoading ? (
            <div className="flex justify-center py-12">
              <Loader2 className="h-7 w-7 animate-spin text-muted-foreground" />
            </div>
          ) : admins.length === 0 ? (
            <p className="text-center py-12 text-muted-foreground">No admin accounts yet.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border">
                    {["Admin", "Email", "Phone", "Machines", "Joined", "Status", ""].map((h) => (
                      <th key={h} className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {admins.map((a) => (
                    <tr key={a.id} className="border-b border-border/30 hover:bg-accent/40 transition-colors">
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-2.5">
                          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-secondary text-xs font-bold text-muted-foreground uppercase shrink-0">
                            {a.username[0]}
                          </div>
                          <span className="text-sm font-medium text-foreground">{a.username}</span>
                        </div>
                      </td>
                      <td className="py-3 px-4 text-sm text-muted-foreground">{a.email}</td>
                      <td className="py-3 px-4 text-sm font-mono text-muted-foreground">{a.phone ?? "—"}</td>
                      <td className="py-3 px-4">
                        <span className="inline-flex items-center gap-1 text-sm font-semibold text-foreground">
                          <Monitor className="h-3.5 w-3.5 text-muted-foreground" />{a.machine_count}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-xs text-muted-foreground font-mono">{fmt(a.created_at)}</td>
                      <td className="py-3 px-4">
                        <Badge className={a.is_active === "true"
                          ? "bg-emerald-500/10 text-emerald-500 border-0 text-xs"
                          : "bg-red-500/10 text-red-500 border-0 text-xs"}>
                          {a.is_active === "true" ? "ACTIVE" : "INACTIVE"}
                        </Badge>
                      </td>
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-1 justify-end">
                          <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => setSelected(a)}>
                            <Eye className="h-3.5 w-3.5" />
                          </Button>
                          <Button
                            variant="ghost" size="icon"
                            className={`h-7 w-7 ${a.is_active === "true" ? "text-red-500 hover:text-red-400" : "text-emerald-500 hover:text-emerald-400"}`}
                            disabled={toggleMutation.isPending}
                            onClick={() => toggleMutation.mutate({ id: a.id, active: a.is_active !== "true" })}
                          >
                            {a.is_active === "true" ? <ShieldOff className="h-3.5 w-3.5" /> : <ShieldCheck className="h-3.5 w-3.5" />}
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {/* Detail dialog */}
      <Dialog open={!!selected} onOpenChange={(o) => !o && setSelected(null)}>
        <DialogContent className="bg-card border-border max-w-lg">
          <DialogHeader>
            <DialogTitle>{selected?.username}</DialogTitle>
            <DialogDescription>Admin account details</DialogDescription>
          </DialogHeader>
          {detailLoading ? (
            <div className="flex justify-center py-8"><Loader2 className="h-6 w-6 animate-spin text-muted-foreground" /></div>
          ) : detail ? (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-3 text-sm">
                {[
                  ["Email", detail.email],
                  ["Phone", detail.phone ?? "—"],
                  ["Machines", String(detail.machine_count)],
                  ["Pending UPI", String(detail.pending_upi_requests)],
                  ["Status", detail.is_active === "true" ? "Active" : "Inactive"],
                  ["Joined", fmt(detail.created_at)],
                ].map(([k, v]) => (
                  <div key={k}>
                    <p className="text-xs text-muted-foreground uppercase tracking-wider mb-0.5">{k}</p>
                    <p className="font-medium">{v}</p>
                  </div>
                ))}
              </div>
              {detail.machines.length > 0 && (
                <div>
                  <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-2">Machines</p>
                  <div className="space-y-2 max-h-48 overflow-y-auto pr-1">
                    {detail.machines.map((m) => (
                      <div key={m.id} className="flex items-center justify-between rounded-lg border border-border/50 px-3 py-2">
                        <div>
                          <p className="text-sm font-medium">{m.name}</p>
                          <p className="text-xs text-muted-foreground">{m.location}</p>
                        </div>
                        <div className="text-right">
                          <span className={`text-[10px] font-bold uppercase ${m.status === "online" ? "text-emerald-500" : "text-red-500"}`}>
                            {m.status}
                          </span>
                          <p className="text-xs font-mono text-muted-foreground mt-0.5">{m.upi_id ?? "No UPI"}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ) : null}
        </DialogContent>
      </Dialog>

      {/* Create dialog */}
      <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
        <DialogContent className="bg-card border-border">
          <DialogHeader>
            <DialogTitle>Create Admin Account</DialogTitle>
            <DialogDescription>New admin can manage their own machines and catalogue</DialogDescription>
          </DialogHeader>
          <form onSubmit={(e) => { e.preventDefault(); createMutation.mutate({ ...form, phone: form.phone || undefined }); }} className="space-y-4">
            {[
              { label: "Username", key: "username", type: "text", placeholder: "e.g. ramesh_admin" },
              { label: "Email", key: "email", type: "email", placeholder: "admin@example.com" },
              { label: "Phone (optional)", key: "phone", type: "tel", placeholder: "+91 9876543210" },
              { label: "Password", key: "password", type: "password", placeholder: "Min 6 characters" },
            ].map(({ label, key, type, placeholder }) => (
              <div key={key}>
                <Label>{label}</Label>
                <Input
                  type={type}
                  value={form[key as keyof typeof form]}
                  onChange={(e) => setForm({ ...form, [key]: e.target.value })}
                  placeholder={placeholder}
                  className="bg-secondary/50"
                  required={key !== "phone"}
                  minLength={key === "password" ? 6 : undefined}
                />
              </div>
            ))}
            <div className="flex justify-end gap-3">
              <Button type="button" variant="outline" onClick={() => setIsCreateOpen(false)}>Cancel</Button>
              <Button type="submit" variant="glow" disabled={createMutation.isPending}>
                {createMutation.isPending ? "Creating..." : "Create Admin"}
              </Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </SuperAdminLayout>
  );
};

export default AdminsPage;
