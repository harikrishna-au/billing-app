import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useToast } from "@/hooks/use-toast";
import {
  superadminApi,
  type AdminSummary,
  type UpiRequest,
  type SuperMachine,
} from "@/lib/api/superadmin";
import {
  Users,
  Monitor,
  CreditCard,
  CheckCircle,
  XCircle,
  Plus,
  Loader2,
  Eye,
  ShieldCheck,
  ShieldOff,
  ArrowRight,
  Clock,
} from "lucide-react";

// ─── Helpers ─────────────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: string }) {
  if (status === "online")
    return <Badge className="bg-emerald-500/10 text-emerald-500 border-0 text-xs">ONLINE</Badge>;
  if (status === "offline")
    return <Badge className="bg-red-500/10 text-red-500 border-0 text-xs">OFFLINE</Badge>;
  return <Badge className="bg-amber-500/10 text-amber-500 border-0 text-xs">{status.toUpperCase()}</Badge>;
}

function RequestStatusBadge({ status }: { status: string }) {
  if (status === "pending")
    return <Badge className="bg-amber-500/10 text-amber-500 border-amber-500/20 text-xs">PENDING</Badge>;
  if (status === "approved")
    return <Badge className="bg-emerald-500/10 text-emerald-500 border-emerald-500/20 text-xs">APPROVED</Badge>;
  return <Badge className="bg-red-500/10 text-red-500 border-red-500/20 text-xs">REJECTED</Badge>;
}

function fmt(iso: string | null) {
  if (!iso) return "—";
  return new Date(iso).toLocaleString();
}

// ─── Admins tab ───────────────────────────────────────────────────────────────

function AdminsTab() {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [selectedAdmin, setSelectedAdmin] = useState<AdminSummary | null>(null);
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [form, setForm] = useState({ username: "", email: "", phone: "", password: "" });

  const { data: admins = [], isLoading } = useQuery({
    queryKey: ["sa-admins"],
    queryFn: superadminApi.listAdmins,
    refetchInterval: 30_000,
  });

  const { data: adminDetail, isLoading: detailLoading } = useQuery({
    queryKey: ["sa-admin-detail", selectedAdmin?.id],
    queryFn: () => superadminApi.getAdmin(selectedAdmin!.id),
    enabled: !!selectedAdmin,
  });

  const createMutation = useMutation({
    mutationFn: superadminApi.createAdmin,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["sa-admins"] });
      toast({ title: "Admin created successfully" });
      setIsCreateOpen(false);
      setForm({ username: "", email: "", phone: "", password: "" });
    },
    onError: (e: any) =>
      toast({ title: "Error", description: e?.response?.data?.detail || "Failed to create admin", variant: "destructive" }),
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) =>
      superadminApi.toggleAdminStatus(id, active),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["sa-admins"] });
      toast({ title: "Admin status updated" });
    },
    onError: () => toast({ title: "Error", description: "Failed to update status", variant: "destructive" }),
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">{admins.length} admin account{admins.length !== 1 ? "s" : ""}</p>
        <Button variant="glow" size="sm" onClick={() => setIsCreateOpen(true)}>
          <Plus className="h-4 w-4 mr-1" />
          New Admin
        </Button>
      </div>

      {isLoading ? (
        <div className="flex justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      ) : admins.length === 0 ? (
        <p className="text-center py-12 text-muted-foreground">No admin accounts yet.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border">
                {["Username", "Email", "Phone", "Machines", "Joined", "Status", "Actions"].map((h) => (
                  <th key={h} className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {admins.map((a) => (
                <tr key={a.id} className="border-b border-border/30 hover:bg-accent/50 transition-colors">
                  <td className="py-3 px-4 font-medium text-foreground text-sm font-mono">{a.username}</td>
                  <td className="py-3 px-4 text-sm text-muted-foreground">{a.email}</td>
                  <td className="py-3 px-4 text-sm text-muted-foreground font-mono">{a.phone ?? "—"}</td>
                  <td className="py-3 px-4">
                    <span className="inline-flex items-center gap-1 text-sm font-semibold text-foreground">
                      <Monitor className="h-3.5 w-3.5 text-muted-foreground" />
                      {a.machine_count}
                    </span>
                  </td>
                  <td className="py-3 px-4 text-xs text-muted-foreground font-mono">{fmt(a.created_at)}</td>
                  <td className="py-3 px-4">
                    <Badge
                      className={
                        a.is_active === "true"
                          ? "bg-emerald-500/10 text-emerald-500 border-0 text-xs"
                          : "bg-red-500/10 text-red-500 border-0 text-xs"
                      }
                    >
                      {a.is_active === "true" ? "ACTIVE" : "INACTIVE"}
                    </Badge>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-1">
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-7 w-7"
                        title="View details"
                        onClick={() => setSelectedAdmin(a)}
                      >
                        <Eye className="h-3.5 w-3.5" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        className={`h-7 w-7 ${a.is_active === "true" ? "text-red-500 hover:text-red-400" : "text-emerald-500 hover:text-emerald-400"}`}
                        title={a.is_active === "true" ? "Deactivate" : "Activate"}
                        disabled={toggleMutation.isPending}
                        onClick={() => toggleMutation.mutate({ id: a.id, active: a.is_active !== "true" })}
                      >
                        {a.is_active === "true" ? (
                          <ShieldOff className="h-3.5 w-3.5" />
                        ) : (
                          <ShieldCheck className="h-3.5 w-3.5" />
                        )}
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Admin Detail Dialog */}
      <Dialog open={!!selectedAdmin} onOpenChange={(o) => !o && setSelectedAdmin(null)}>
        <DialogContent className="bg-card border-border max-w-xl">
          <DialogHeader>
            <DialogTitle>Admin: {selectedAdmin?.username}</DialogTitle>
            <DialogDescription>Machine portfolio and account details</DialogDescription>
          </DialogHeader>
          {detailLoading ? (
            <div className="flex justify-center py-8">
              <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
            </div>
          ) : adminDetail ? (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-3 text-sm">
                <div>
                  <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Email</p>
                  <p className="font-medium">{adminDetail.email}</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Phone</p>
                  <p className="font-mono">{adminDetail.phone ?? "—"}</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Machines</p>
                  <p className="font-semibold text-lg">{adminDetail.machine_count}</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Pending UPI Requests</p>
                  <p className={`font-semibold text-lg ${adminDetail.pending_upi_requests > 0 ? "text-amber-500" : ""}`}>
                    {adminDetail.pending_upi_requests}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Status</p>
                  <Badge className={adminDetail.is_active === "true" ? "bg-emerald-500/10 text-emerald-500 border-0" : "bg-red-500/10 text-red-500 border-0"}>
                    {adminDetail.is_active === "true" ? "ACTIVE" : "INACTIVE"}
                  </Badge>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Joined</p>
                  <p className="text-xs font-mono">{fmt(adminDetail.created_at)}</p>
                </div>
              </div>
              {adminDetail.machines.length > 0 && (
                <div>
                  <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-2">Machines</p>
                  <div className="space-y-2 max-h-48 overflow-y-auto pr-1">
                    {adminDetail.machines.map((m) => (
                      <div key={m.id} className="flex items-center justify-between rounded-lg border border-border/50 px-3 py-2">
                        <div>
                          <p className="text-sm font-medium">{m.name}</p>
                          <p className="text-xs text-muted-foreground">{m.location}</p>
                        </div>
                        <div className="text-right">
                          <StatusBadge status={m.status} />
                          <p className="text-xs text-muted-foreground font-mono mt-1">{m.upi_id ?? "No UPI"}</p>
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

      {/* Create Admin Dialog */}
      <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
        <DialogContent className="bg-card border-border">
          <DialogHeader>
            <DialogTitle>Create Admin Account</DialogTitle>
            <DialogDescription>New admin can manage their own machines and catalogue</DialogDescription>
          </DialogHeader>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              createMutation.mutate({ ...form, phone: form.phone || undefined });
            }}
            className="space-y-4"
          >
            <div>
              <Label>Username</Label>
              <Input
                value={form.username}
                onChange={(e) => setForm({ ...form, username: e.target.value })}
                placeholder="e.g. ramesh_admin"
                className="bg-secondary/50"
                required
              />
            </div>
            <div>
              <Label>Email</Label>
              <Input
                type="email"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
                placeholder="admin@example.com"
                className="bg-secondary/50"
                required
              />
            </div>
            <div>
              <Label>Phone (optional)</Label>
              <Input
                value={form.phone}
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
                placeholder="+91 9876543210"
                className="bg-secondary/50"
              />
            </div>
            <div>
              <Label>Password</Label>
              <Input
                type="password"
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                placeholder="Min 6 characters"
                className="bg-secondary/50"
                required
                minLength={6}
              />
            </div>
            <div className="flex justify-end gap-3">
              <Button type="button" variant="outline" onClick={() => setIsCreateOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" variant="glow" disabled={createMutation.isPending}>
                {createMutation.isPending ? "Creating..." : "Create Admin"}
              </Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}

// ─── UPI Approvals tab ────────────────────────────────────────────────────────

function UpiApprovalsTab() {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [filter, setFilter] = useState<string>("pending");
  const [rejectDialog, setRejectDialog] = useState<UpiRequest | null>(null);
  const [rejectNote, setRejectNote] = useState("");

  const { data: requests = [], isLoading } = useQuery({
    queryKey: ["sa-upi-requests", filter],
    queryFn: () => superadminApi.listUpiRequests(filter || undefined),
    refetchInterval: 20_000,
  });

  const approveMutation = useMutation({
    mutationFn: superadminApi.approveUpiRequest,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["sa-upi-requests"] });
      toast({ title: "UPI change approved and applied" });
    },
    onError: (e: any) =>
      toast({ title: "Error", description: e?.response?.data?.detail || "Failed to approve", variant: "destructive" }),
  });

  const rejectMutation = useMutation({
    mutationFn: ({ id, note }: { id: string; note: string }) =>
      superadminApi.rejectUpiRequest(id, note),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["sa-upi-requests"] });
      toast({ title: "UPI request rejected" });
      setRejectDialog(null);
      setRejectNote("");
    },
    onError: (e: any) =>
      toast({ title: "Error", description: e?.response?.data?.detail || "Failed to reject", variant: "destructive" }),
  });

  const pendingCount = requests.filter((r) => r.status === "pending").length;

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        {(["pending", "approved", "rejected", ""] as const).map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-3 py-1 rounded-full text-xs font-semibold border transition-colors ${
              filter === f
                ? "bg-primary text-primary-foreground border-primary"
                : "border-border text-muted-foreground hover:text-foreground"
            }`}
          >
            {f === "" ? "All" : f.charAt(0).toUpperCase() + f.slice(1)}
            {f === "pending" && pendingCount > 0 && (
              <span className="ml-1.5 bg-amber-500 text-white rounded-full px-1.5 py-0.5 text-[10px] font-bold">
                {pendingCount}
              </span>
            )}
          </button>
        ))}
      </div>

      {isLoading ? (
        <div className="flex justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      ) : requests.length === 0 ? (
        <div className="text-center py-12 text-muted-foreground">
          <Clock className="h-8 w-8 mx-auto mb-3 opacity-30" />
          <p>No {filter || ""} UPI change requests.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {requests.map((r) => (
            <div
              key={r.id}
              className="rounded-xl border border-border/60 bg-secondary/20 p-4"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-2">
                    <RequestStatusBadge status={r.status} />
                    <span className="text-sm font-semibold text-foreground truncate">{r.machine_name}</span>
                    <span className="text-xs text-muted-foreground">by {r.requested_by}</span>
                  </div>

                  <div className="flex items-center gap-2 text-sm font-mono">
                    <span className="text-muted-foreground">{r.old_upi_id || <em className="not-italic text-muted-foreground/50">not set</em>}</span>
                    <ArrowRight className="h-3 w-3 text-muted-foreground shrink-0" />
                    <span className="text-primary font-semibold">{r.new_upi_id}</span>
                  </div>

                  <p className="text-xs text-muted-foreground mt-1.5">Requested {fmt(r.created_at)}</p>

                  {r.superadmin_note && (
                    <p className="text-xs text-muted-foreground mt-1 italic">Note: {r.superadmin_note}</p>
                  )}
                </div>

                {r.status === "pending" && (
                  <div className="flex gap-2 shrink-0">
                    <Button
                      size="sm"
                      variant="outline"
                      className="border-red-500/30 text-red-500 hover:bg-red-500/10 h-8"
                      disabled={rejectMutation.isPending || approveMutation.isPending}
                      onClick={() => { setRejectDialog(r); setRejectNote(""); }}
                    >
                      <XCircle className="h-3.5 w-3.5 mr-1" />
                      Reject
                    </Button>
                    <Button
                      size="sm"
                      variant="glow"
                      className="h-8"
                      disabled={approveMutation.isPending || rejectMutation.isPending}
                      onClick={() => approveMutation.mutate(r.id)}
                    >
                      <CheckCircle className="h-3.5 w-3.5 mr-1" />
                      Approve
                    </Button>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Reject dialog */}
      <Dialog open={!!rejectDialog} onOpenChange={(o) => !o && setRejectDialog(null)}>
        <DialogContent className="bg-card border-border">
          <DialogHeader>
            <DialogTitle>Reject UPI Request</DialogTitle>
            <DialogDescription>
              Rejecting UPI change for <strong>{rejectDialog?.machine_name}</strong> →{" "}
              <span className="font-mono">{rejectDialog?.new_upi_id}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <Label>Reason (optional)</Label>
              <Input
                value={rejectNote}
                onChange={(e) => setRejectNote(e.target.value)}
                placeholder="e.g. Invalid UPI ID format"
                className="bg-secondary/50"
              />
            </div>
            <div className="flex justify-end gap-3">
              <Button variant="outline" onClick={() => setRejectDialog(null)}>
                Cancel
              </Button>
              <Button
                variant="destructive"
                disabled={rejectMutation.isPending}
                onClick={() => rejectMutation.mutate({ id: rejectDialog!.id, note: rejectNote })}
              >
                {rejectMutation.isPending ? "Rejecting..." : "Confirm Reject"}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

// ─── All Machines tab ─────────────────────────────────────────────────────────

function AllMachinesTab() {
  const [search, setSearch] = useState("");

  const { data: machines = [], isLoading } = useQuery({
    queryKey: ["sa-machines"],
    queryFn: superadminApi.listMachines,
    refetchInterval: 30_000,
  });

  const filtered = machines.filter(
    (m) =>
      m.name.toLowerCase().includes(search.toLowerCase()) ||
      m.admin.toLowerCase().includes(search.toLowerCase()) ||
      m.location.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-4">
      <div className="relative w-64">
        <Monitor className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
        <Input
          placeholder="Search machines or admins..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="pl-10 bg-secondary/50"
        />
      </div>

      {isLoading ? (
        <div className="flex justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      ) : filtered.length === 0 ? (
        <p className="text-center py-12 text-muted-foreground">No machines found.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border">
                {["Machine", "Location", "Admin", "UPI ID", "Status", "Last Sync"].map((h) => (
                  <th key={h} className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((m) => (
                <tr key={m.id} className="border-b border-border/30 hover:bg-accent/50 transition-colors">
                  <td className="py-3 px-4 font-medium text-foreground text-sm">{m.name}</td>
                  <td className="py-3 px-4 text-sm text-muted-foreground">{m.location}</td>
                  <td className="py-3 px-4 text-sm text-muted-foreground font-mono">{m.admin}</td>
                  <td className="py-3 px-4 text-xs font-mono text-muted-foreground">
                    {m.upi_id ?? <span className="italic opacity-50">not set</span>}
                  </td>
                  <td className="py-3 px-4">
                    <StatusBadge status={m.status} />
                  </td>
                  <td className="py-3 px-4 text-xs text-muted-foreground font-mono">{fmt(m.last_sync)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

const SuperAdmin = () => {
  const userStr = localStorage.getItem("user");
  const user = userStr ? JSON.parse(userStr) : null;

  if (!user || user.role !== "superadmin") {
    return (
      <DashboardLayout>
        <div className="flex flex-col items-center justify-center py-24 text-center space-y-4">
          <ShieldOff className="h-12 w-12 text-muted-foreground/30" />
          <p className="text-lg font-semibold text-foreground">Access Denied</p>
          <p className="text-sm text-muted-foreground">
            This page is only accessible to superadmin accounts.
          </p>
        </div>
      </DashboardLayout>
    );
  }

  const { data: pendingCount = 0 } = useQuery({
    queryKey: ["sa-pending-count"],
    queryFn: async () => {
      const reqs = await superadminApi.listUpiRequests("pending");
      return reqs.length;
    },
    refetchInterval: 20_000,
  });

  return (
    <DashboardLayout>
      <div className="space-y-8">
        <div className="animate-fade-in">
          <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-1">
            Superadmin
          </p>
          <h1 className="text-2xl font-semibold text-foreground">Control Panel</h1>
          <p className="text-sm text-muted-foreground">
            Manage admins, approve UPI changes, and oversee all machines
          </p>
        </div>

        <div className="stat-card animate-slide-up">
          <Tabs defaultValue="admins">
            <TabsList className="mb-6">
              <TabsTrigger value="admins" className="flex items-center gap-1.5">
                <Users className="h-3.5 w-3.5" />
                Admins
              </TabsTrigger>
              <TabsTrigger value="upi" className="flex items-center gap-1.5 relative">
                <CreditCard className="h-3.5 w-3.5" />
                UPI Approvals
                {pendingCount > 0 && (
                  <span className="ml-1 bg-amber-500 text-white rounded-full px-1.5 py-0.5 text-[10px] font-bold">
                    {pendingCount}
                  </span>
                )}
              </TabsTrigger>
              <TabsTrigger value="machines" className="flex items-center gap-1.5">
                <Monitor className="h-3.5 w-3.5" />
                All Machines
              </TabsTrigger>
            </TabsList>

            <TabsContent value="admins">
              <AdminsTab />
            </TabsContent>

            <TabsContent value="upi">
              <UpiApprovalsTab />
            </TabsContent>

            <TabsContent value="machines">
              <AllMachinesTab />
            </TabsContent>
          </Tabs>
        </div>
      </div>
    </DashboardLayout>
  );
};

export default SuperAdmin;
