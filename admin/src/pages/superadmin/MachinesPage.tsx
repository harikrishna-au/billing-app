import { useMemo, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import SuperAdminLayout from "@/components/layout/SuperAdminLayout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter,
} from "@/components/ui/dialog";
import { useToast } from "@/hooks/use-toast";
import { superadminApi, type SuperMachine } from "@/lib/api/superadmin";
import { Wifi, WifiOff, Loader2, Search, Monitor, TrendingUp, Banknote, Receipt, ArrowUpDown, Power, PowerOff, Ban } from "lucide-react";

type Period = "today" | "month" | "total";
type SortKey = "collection" | "name" | "admin";

const PERIOD_LABELS: Record<Period, string> = {
  today: "Today",
  month: "This Month",
  total: "All Time",
};

function fmt(iso: string | null) {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

function money(n: number) {
  return `₹${n.toLocaleString("en-IN", { maximumFractionDigits: 2 })}`;
}

function collectionFor(m: SuperMachine, period: Period) {
  const online = period === "today" ? m.today_online : period === "month" ? m.month_online : m.total_online;
  const offline = period === "today" ? m.today_offline : period === "month" ? m.month_offline : m.total_offline;
  const bills = period === "today" ? m.today_bills : period === "month" ? m.month_bills : m.total_bills;
  return { online: Number(online) || 0, offline: Number(offline) || 0, bills: Number(bills) || 0 };
}

const MachinesPage = () => {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<"all" | "online" | "offline">("all");
  const [period, setPeriod] = useState<Period>("today");
  const [sortKey, setSortKey] = useState<SortKey>("collection");
  const [confirmTarget, setConfirmTarget] = useState<SuperMachine | null>(null);

  const { data: machines = [], isLoading } = useQuery({
    queryKey: ["sa-machines"],
    queryFn: superadminApi.listMachines,
    refetchInterval: 30_000,
  });

  const activeMutation = useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) => superadminApi.setMachineActive(id, active),
    onSuccess: (_data, { active }) => {
      qc.invalidateQueries({ queryKey: ["sa-machines"] });
      setConfirmTarget(null);
      toast({
        title: active ? "Machine activated" : "Machine deactivated",
        description: active
          ? "It can log in and bill again."
          : "It can no longer log in or bill, effective immediately.",
      });
    },
    onError: (e: unknown) => {
      const detail = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      toast({ title: "Error", description: detail || "Failed to update machine", variant: "destructive" });
    },
  });

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    const rows = machines.filter((m) => {
      const matchSearch =
        !q ||
        m.name.toLowerCase().includes(q) ||
        m.location?.toLowerCase().includes(q) ||
        m.admin?.toLowerCase().includes(q);
      const matchStatus = statusFilter === "all" || m.status === statusFilter;
      return matchSearch && matchStatus;
    });

    return [...rows].sort((a, b) => {
      if (sortKey === "name") return a.name.localeCompare(b.name);
      if (sortKey === "admin") return (a.admin ?? "").localeCompare(b.admin ?? "");
      const ca = collectionFor(a, period);
      const cb = collectionFor(b, period);
      return cb.online + cb.offline - (ca.online + ca.offline);
    });
  }, [machines, search, statusFilter, sortKey, period]);

  const totals = useMemo(
    () =>
      filtered.reduce(
        (acc, m) => {
          const c = collectionFor(m, period);
          acc.online += c.online;
          acc.offline += c.offline;
          acc.bills += c.bills;
          return acc;
        },
        { online: 0, offline: 0, bills: 0 }
      ),
    [filtered, period]
  );

  const online = machines.filter((m) => m.status === "online").length;
  const offline = machines.length - online;
  const grandTotal = totals.online + totals.offline;

  const exportCsv = () => {
    const header = ["Machine", "Location", "Admin", "Status", "Online (UPI+Card)", "Cash", "Total", "Bills"];
    const rows = filtered.map((m) => {
      const c = collectionFor(m, period);
      return [m.name, m.location ?? "", m.admin ?? "", m.status ?? "", c.online, c.offline, c.online + c.offline, c.bills];
    });
    const csv = [header, ...rows]
      .map((r) => r.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(","))
      .join("\n");
    const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8;" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = `machine-collection-${period}-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  return (
    <SuperAdminLayout>
      <div className="space-y-6">
        <div className="animate-fade-in">
          <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-1">Superadmin</p>
          <h1 className="text-2xl font-semibold text-foreground">All Machines</h1>
          <p className="text-sm text-muted-foreground">
            Collection across every machine and admin · {PERIOD_LABELS[period]}
          </p>
        </div>

        {/* Summary row */}
        <div className="grid grid-cols-2 lg:grid-cols-5 gap-4 animate-slide-up">
          {[
            { label: "Machines", value: `${machines.length}`, sub: `${online} online · ${offline} offline`, icon: Monitor, color: "" },
            { label: `${PERIOD_LABELS[period]} Total`, value: money(grandTotal), sub: `${totals.bills} bills`, icon: TrendingUp, color: "text-emerald-600" },
            { label: "Online (UPI + Card)", value: money(totals.online), sub: "settles to bank", icon: Wifi, color: "text-blue-500" },
            { label: "Cash", value: money(totals.offline), sub: "collected at counter", icon: Banknote, color: "text-amber-500" },
            { label: "Bills", value: totals.bills.toLocaleString("en-IN"), sub: PERIOD_LABELS[period], icon: Receipt, color: "text-muted-foreground" },
          ].map(({ label, value, sub, icon: Icon, color }) => (
            <div key={label} className="stat-card p-4 flex items-center gap-3">
              <Icon className={`h-5 w-5 shrink-0 ${color || "text-muted-foreground"}`} />
              <div className="min-w-0">
                <p className="text-xs text-muted-foreground uppercase tracking-wider truncate">{label}</p>
                <p className="text-xl font-bold text-foreground truncate">{value}</p>
                <p className="text-[11px] text-muted-foreground truncate">{sub}</p>
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

          <div className="flex items-center gap-1 rounded-full border border-border p-0.5">
            {(Object.keys(PERIOD_LABELS) as Period[]).map((p) => (
              <button
                key={p}
                onClick={() => setPeriod(p)}
                className={`px-3 py-1 rounded-full text-xs font-semibold transition-colors ${
                  period === p ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-foreground"
                }`}
              >
                {PERIOD_LABELS[p]}
              </button>
            ))}
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

          <button
            onClick={() => setSortKey(sortKey === "collection" ? "name" : sortKey === "name" ? "admin" : "collection")}
            className="ml-auto flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold border border-border text-muted-foreground hover:text-foreground hover:border-foreground/30 transition-colors"
          >
            <ArrowUpDown className="h-3 w-3" />
            Sort: {sortKey === "collection" ? "Collection" : sortKey === "name" ? "Name" : "Admin"}
          </button>

          <button
            onClick={exportCsv}
            disabled={filtered.length === 0}
            className="px-3 py-1.5 rounded-full text-xs font-semibold border border-border text-muted-foreground hover:text-foreground hover:border-foreground/30 transition-colors disabled:opacity-40"
          >
            Export CSV
          </button>
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
                    {["Machine", "Location", "Admin", "Status", "Online", "Cash", "Total", "Bills", "Added", ""].map((h, i) => (
                      <th
                        key={h || "actions"}
                        className={`py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground ${
                          i >= 4 && i <= 7 ? "text-right" : "text-left"
                        }`}
                      >
                        {h}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((m) => {
                    const c = collectionFor(m, period);
                    const total = c.online + c.offline;
                    const disabled = m.is_active === "false";
                    return (
                      <tr
                        key={m.id}
                        className={`border-b border-border/30 hover:bg-accent/40 transition-colors ${disabled ? "opacity-60" : ""}`}
                      >
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-2">
                            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-secondary shrink-0">
                              <Monitor className="h-3.5 w-3.5 text-muted-foreground" />
                            </div>
                            <div className="min-w-0">
                              <p className="text-sm font-medium text-foreground truncate">{m.name}</p>
                              <p className="font-mono text-[11px] text-muted-foreground truncate">{m.upi_id ?? "no UPI"}</p>
                            </div>
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
                        <td className="py-3 px-4">
                          {disabled ? (
                            <Badge className="bg-muted text-muted-foreground border-0 text-xs gap-1">
                              <Ban className="h-2.5 w-2.5" />
                              DEACTIVATED
                            </Badge>
                          ) : (
                            <Badge
                              className={
                                m.status === "online"
                                  ? "bg-emerald-500/10 text-emerald-500 border-0 text-xs gap-1"
                                  : "bg-red-500/10 text-red-500 border-0 text-xs gap-1"
                              }
                            >
                              {m.status === "online" ? <Wifi className="h-2.5 w-2.5" /> : <WifiOff className="h-2.5 w-2.5" />}
                              {m.status?.toUpperCase() ?? "UNKNOWN"}
                            </Badge>
                          )}
                        </td>
                        <td className="py-3 px-4 text-right text-sm font-mono text-blue-600">{money(c.online)}</td>
                        <td className="py-3 px-4 text-right text-sm font-mono text-amber-600">{money(c.offline)}</td>
                        <td className="py-3 px-4 text-right text-sm font-mono font-semibold text-foreground">{money(total)}</td>
                        <td className="py-3 px-4 text-right text-sm font-mono text-muted-foreground">{c.bills}</td>
                        <td className="py-3 px-4 text-xs font-mono text-muted-foreground">{fmt(m.created_at ?? null)}</td>
                        <td className="py-3 px-4 text-right">
                          {disabled ? (
                            <Button
                              size="sm"
                              variant="outline"
                              className="h-7 gap-1.5 text-xs"
                              disabled={activeMutation.isPending}
                              onClick={() => activeMutation.mutate({ id: m.id, active: true })}
                            >
                              <Power className="h-3 w-3" />
                              Activate
                            </Button>
                          ) : (
                            <Button
                              size="sm"
                              variant="ghost"
                              className="h-7 gap-1.5 text-xs text-red-500 hover:text-red-600 hover:bg-red-500/10"
                              onClick={() => setConfirmTarget(m)}
                            >
                              <PowerOff className="h-3 w-3" />
                              Deactivate
                            </Button>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
                <tfoot>
                  <tr className="border-t border-border bg-secondary/30">
                    <td className="py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground" colSpan={4}>
                      {filtered.length} machine{filtered.length === 1 ? "" : "s"}
                    </td>
                    <td className="py-3 px-4 text-right text-sm font-mono font-semibold text-blue-600">{money(totals.online)}</td>
                    <td className="py-3 px-4 text-right text-sm font-mono font-semibold text-amber-600">{money(totals.offline)}</td>
                    <td className="py-3 px-4 text-right text-sm font-mono font-bold text-foreground">{money(grandTotal)}</td>
                    <td className="py-3 px-4 text-right text-sm font-mono font-semibold text-muted-foreground">{totals.bills}</td>
                    <td />
                    <td />
                  </tr>
                </tfoot>
              </table>
            </div>
          )}
        </div>

        <Dialog open={!!confirmTarget} onOpenChange={(open) => !open && setConfirmTarget(null)}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Deactivate {confirmTarget?.name}?</DialogTitle>
              <DialogDescription asChild>
                <div className="space-y-2 text-sm">
                  <p>
                    The terminal stops working immediately — it cannot log in, record bills, or sync. This
                    applies to the device even if it is already signed in.
                  </p>
                  <p>
                    Any bills held offline on that device will fail to upload until you activate it again.
                    Past collection stays on record.
                  </p>
                </div>
              </DialogDescription>
            </DialogHeader>
            <DialogFooter>
              <Button variant="outline" onClick={() => setConfirmTarget(null)}>
                Cancel
              </Button>
              <Button
                variant="destructive"
                disabled={activeMutation.isPending}
                onClick={() => confirmTarget && activeMutation.mutate({ id: confirmTarget.id, active: false })}
              >
                {activeMutation.isPending && <Loader2 className="h-3.5 w-3.5 animate-spin mr-1.5" />}
                Deactivate
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </SuperAdminLayout>
  );
};

export default MachinesPage;
