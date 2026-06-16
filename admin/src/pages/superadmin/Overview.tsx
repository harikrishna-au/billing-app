import { useQuery } from "@tanstack/react-query";
import SuperAdminLayout from "@/components/layout/SuperAdminLayout";
import { superadminApi } from "@/lib/api/superadmin";
import { Users, Monitor, CreditCard, Wifi, WifiOff, Clock } from "lucide-react";
import { Loader2 } from "lucide-react";

function StatCard({
  label,
  value,
  icon: Icon,
  accent,
  sub,
}: {
  label: string;
  value: string | number;
  icon: React.ElementType;
  accent?: string;
  sub?: string;
}) {
  return (
    <div className="stat-card p-5 flex items-start gap-4">
      <div className={`flex h-10 w-10 items-center justify-center rounded-xl shrink-0 ${accent ?? "bg-primary/10"}`}>
        <Icon className={`h-5 w-5 ${accent ? "text-white" : "text-primary"}`} />
      </div>
      <div>
        <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-1">{label}</p>
        <p className="text-2xl font-bold text-foreground leading-none">{value}</p>
        {sub && <p className="text-xs text-muted-foreground mt-1">{sub}</p>}
      </div>
    </div>
  );
}

function fmt(iso: string | null) {
  if (!iso) return "—";
  return new Date(iso).toLocaleString();
}

const Overview = () => {
  const { data: admins = [], isLoading: adminsLoading } = useQuery({
    queryKey: ["sa-admins"],
    queryFn: superadminApi.listAdmins,
  });

  const { data: machines = [], isLoading: machinesLoading } = useQuery({
    queryKey: ["sa-machines"],
    queryFn: superadminApi.listMachines,
  });

  const { data: pendingRequests = [], isLoading: reqLoading } = useQuery({
    queryKey: ["sa-upi-requests", "pending"],
    queryFn: () => superadminApi.listUpiRequests("pending"),
    refetchInterval: 20_000,
  });

  const { data: recentRequests = [] } = useQuery({
    queryKey: ["sa-upi-requests", ""],
    queryFn: () => superadminApi.listUpiRequests(),
  });

  const activeAdmins = admins.filter((a) => a.is_active === "true").length;
  const onlineMachines = machines.filter((m) => m.status === "online").length;
  const isLoading = adminsLoading || machinesLoading || reqLoading;

  const user = (() => {
    try { return JSON.parse(localStorage.getItem("user") || "{}"); } catch { return {}; }
  })();

  const hour = new Date().getHours();
  const greeting = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening";

  return (
    <SuperAdminLayout>
      <div className="space-y-8">
        {/* Header */}
        <div className="animate-fade-in">
          <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-1">
            Superadmin Portal
          </p>
          <h1 className="text-2xl font-semibold text-foreground">
            {greeting}, {user.username ?? "Superadmin"}
          </h1>
          <p className="text-sm text-muted-foreground">Here's what's happening across all admins and machines.</p>
        </div>

        {isLoading ? (
          <div className="flex justify-center py-16">
            <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
          </div>
        ) : (
          <>
            {/* Stats */}
            <div className="grid grid-cols-2 md:grid-cols-3 gap-4 animate-slide-up">
              <StatCard label="Total Admins"    value={admins.length}    icon={Users}    sub={`${activeAdmins} active`} />
              <StatCard label="Total Machines"  value={machines.length}  icon={Monitor}  sub={`${onlineMachines} online`} />
              <StatCard
                label="Pending UPI"
                value={pendingRequests.length}
                icon={CreditCard}
                accent={pendingRequests.length > 0 ? "bg-amber-500" : undefined}
                sub={pendingRequests.length > 0 ? "Needs your approval" : "All clear"}
              />
              <StatCard label="Active Admins"   value={activeAdmins}     icon={Users}    sub={`${admins.length - activeAdmins} inactive`} />
              <StatCard label="Online Machines" value={onlineMachines}   icon={Wifi}     sub="Right now" />
              <StatCard label="Offline Machines" value={machines.length - onlineMachines} icon={WifiOff} sub="Need attention" />
            </div>

            {/* Recent UPI requests */}
            {recentRequests.length > 0 && (
              <div className="stat-card animate-slide-up" style={{ animationDelay: "0.1s" }}>
                <div className="flex items-center gap-2 mb-4">
                  <Clock className="h-4 w-4 text-muted-foreground" />
                  <h2 className="text-sm font-semibold text-foreground">Recent UPI Requests</h2>
                </div>
                <div className="space-y-2">
                  {recentRequests.slice(0, 5).map((r) => (
                    <div key={r.id} className="flex items-center justify-between py-2 border-b border-border/30 last:border-0">
                      <div>
                        <p className="text-sm font-medium text-foreground">{r.machine_name}</p>
                        <p className="text-xs text-muted-foreground">by {r.requested_by} · {fmt(r.created_at)}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-xs font-mono text-primary">{r.new_upi_id}</p>
                        <span className={`text-[10px] font-semibold uppercase ${
                          r.status === "pending" ? "text-amber-500" :
                          r.status === "approved" ? "text-emerald-500" : "text-red-500"
                        }`}>{r.status}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Admin list preview */}
            {admins.length > 0 && (
              <div className="stat-card animate-slide-up" style={{ animationDelay: "0.15s" }}>
                <div className="flex items-center gap-2 mb-4">
                  <Users className="h-4 w-4 text-muted-foreground" />
                  <h2 className="text-sm font-semibold text-foreground">Admin Accounts</h2>
                </div>
                <div className="space-y-2">
                  {admins.slice(0, 5).map((a) => (
                    <div key={a.id} className="flex items-center justify-between py-2 border-b border-border/30 last:border-0">
                      <div className="flex items-center gap-3">
                        <div className="flex h-7 w-7 items-center justify-center rounded-full bg-secondary text-xs font-bold text-muted-foreground uppercase">
                          {a.username[0]}
                        </div>
                        <div>
                          <p className="text-sm font-medium text-foreground">{a.username}</p>
                          <p className="text-xs text-muted-foreground">{a.email}</p>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="text-xs font-semibold text-foreground">{a.machine_count} machines</p>
                        <span className={`text-[10px] font-semibold uppercase ${a.is_active === "true" ? "text-emerald-500" : "text-red-500"}`}>
                          {a.is_active === "true" ? "Active" : "Inactive"}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </SuperAdminLayout>
  );
};

export default Overview;
