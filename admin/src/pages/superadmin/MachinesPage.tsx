import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import SuperAdminLayout from "@/components/layout/SuperAdminLayout";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { superadminApi, type SuperMachine } from "@/lib/api/superadmin";
import { Wifi, WifiOff, Loader2, Search, Monitor } from "lucide-react";

function fmt(iso: string | null) {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

const MachinesPage = () => {
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<"all" | "online" | "offline">("all");

  const { data: machines = [], isLoading } = useQuery({
    queryKey: ["sa-machines"],
    queryFn: superadminApi.listMachines,
    refetchInterval: 30_000,
  });

  const filtered = machines.filter((m) => {
    const q = search.toLowerCase();
    const matchSearch = !q || m.name.toLowerCase().includes(q) || m.location?.toLowerCase().includes(q) || m.admin?.toLowerCase().includes(q);
    const matchStatus = statusFilter === "all" || m.status === statusFilter;
    return matchSearch && matchStatus;
  });

  const online = machines.filter((m) => m.status === "online").length;
  const offline = machines.length - online;

  return (
    <SuperAdminLayout>
      <div className="space-y-6">
        <div className="animate-fade-in">
          <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-1">Superadmin</p>
          <h1 className="text-2xl font-semibold text-foreground">All Machines</h1>
          <p className="text-sm text-muted-foreground">Every machine across all admins</p>
        </div>

        {/* Summary row */}
        <div className="grid grid-cols-3 gap-4 animate-slide-up">
          {[
            { label: "Total", value: machines.length, icon: Monitor, color: "" },
            { label: "Online", value: online, icon: Wifi, color: "text-emerald-500" },
            { label: "Offline", value: offline, icon: WifiOff, color: "text-red-500" },
          ].map(({ label, value, icon: Icon, color }) => (
            <div key={label} className="stat-card p-4 flex items-center gap-3">
              <Icon className={`h-5 w-5 ${color || "text-muted-foreground"}`} />
              <div>
                <p className="text-xs text-muted-foreground uppercase tracking-wider">{label}</p>
                <p className="text-xl font-bold text-foreground">{value}</p>
              </div>
            </div>
          ))}
        </div>

        {/* Filters */}
        <div className="flex items-center gap-3 flex-wrap">
          <div className="relative flex-1 min-w-48 max-w-xs">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
            <Input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search name, location, admin…"
              className="h-8 pl-8 bg-secondary/50 text-sm"
            />
          </div>
          {(["all", "online", "offline"] as const).map((s) => (
            <button
              key={s}
              onClick={() => setStatusFilter(s)}
              className={`px-3 py-1.5 rounded-full text-xs font-semibold border transition-colors ${
                statusFilter === s
                  ? "bg-primary text-primary-foreground border-primary"
                  : "border-border text-muted-foreground hover:text-foreground hover:border-foreground/30"
              }`}
            >
              {s.charAt(0).toUpperCase() + s.slice(1)}
            </button>
          ))}
        </div>

        {/* Table */}
        <div className="stat-card animate-slide-up">
          {isLoading ? (
            <div className="flex justify-center py-12">
              <Loader2 className="h-7 w-7 animate-spin text-muted-foreground" />
            </div>
          ) : filtered.length === 0 ? (
            <div className="py-16 text-center space-y-2">
              <Monitor className="h-10 w-10 mx-auto text-muted-foreground/20" />
              <p className="text-muted-foreground">{search ? "No machines match your search" : "No machines found"}</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border">
                    {["Machine", "Location", "Admin", "UPI ID", "Status", "Added"].map((h) => (
                      <th key={h} className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((m) => (
                    <tr key={m.id} className="border-b border-border/30 hover:bg-accent/40 transition-colors">
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-2">
                          <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-secondary shrink-0">
                            <Monitor className="h-3.5 w-3.5 text-muted-foreground" />
                          </div>
                          <span className="text-sm font-medium text-foreground">{m.name}</span>
                        </div>
                      </td>
                      <td className="py-3 px-4 text-sm text-muted-foreground">{m.location ?? "—"}</td>
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-1.5">
                          <div className="flex h-5 w-5 items-center justify-center rounded-full bg-secondary text-[9px] font-bold uppercase">
                            {m.admin?.[0] ?? "?"}
                          </div>
                          <span className="text-sm text-muted-foreground">{m.admin ?? "—"}</span>
                        </div>
                      </td>
                      <td className="py-3 px-4 font-mono text-xs text-muted-foreground">{m.upi_id ?? "—"}</td>
                      <td className="py-3 px-4">
                        <Badge className={m.status === "online"
                          ? "bg-emerald-500/10 text-emerald-500 border-0 text-xs gap-1"
                          : "bg-red-500/10 text-red-500 border-0 text-xs gap-1"}>
                          {m.status === "online" ? <Wifi className="h-2.5 w-2.5" /> : <WifiOff className="h-2.5 w-2.5" />}
                          {m.status?.toUpperCase() ?? "UNKNOWN"}
                        </Badge>
                      </td>
                      <td className="py-3 px-4 text-xs font-mono text-muted-foreground">{fmt(m.created_at ?? null)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </SuperAdminLayout>
  );
};

export default MachinesPage;
