import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import SuperAdminLayout from "@/components/layout/SuperAdminLayout";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { superadminApi } from "@/lib/api/superadmin";
import { ClipboardList, ChevronLeft, ChevronRight, Loader2, Search, X } from "lucide-react";

function fmt(iso: string | null) {
  if (!iso) return "—";
  return new Date(iso).toLocaleString("en-IN", {
    day: "2-digit", month: "short", year: "numeric",
    hour: "2-digit", minute: "2-digit", second: "2-digit",
  });
}

function actionColor(action: string) {
  if (action.includes("create"))  return "bg-emerald-500/10 text-emerald-400";
  if (action.includes("delete"))  return "bg-red-500/10 text-red-400";
  if (action.includes("approve")) return "bg-blue-500/10 text-blue-400";
  if (action.includes("reject"))  return "bg-orange-500/10 text-orange-400";
  if (action.includes("toggle") || action.includes("status")) return "bg-amber-500/10 text-amber-400";
  return "bg-secondary/60 text-muted-foreground";
}

const ACTION_FILTERS = [
  { label: "All", value: "" },
  { label: "admin.create", value: "admin.create" },
  { label: "admin.status_toggle", value: "admin.status_toggle" },
  { label: "upi.approve", value: "upi.approve" },
  { label: "upi.reject", value: "upi.reject" },
];

const LIMIT = 50;

const AuditLogsPage = () => {
  const [page, setPage] = useState(1);
  const [actionFilter, setActionFilter] = useState("");
  const [search, setSearch] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["sa-audit-logs", page, actionFilter],
    queryFn: () => superadminApi.listAuditLogs({ action: actionFilter || undefined, page, limit: LIMIT }),
    refetchInterval: 30_000,
  });

  const logs = data?.logs ?? [];
  const pagination = data?.pagination ?? { total: 0, page: 1, limit: LIMIT };
  const totalPages = Math.ceil(pagination.total / LIMIT) || 1;

  const filtered = search
    ? logs.filter((l) =>
        l.actor_username.toLowerCase().includes(search.toLowerCase()) ||
        l.action.toLowerCase().includes(search.toLowerCase()) ||
        l.details?.toLowerCase().includes(search.toLowerCase())
      )
    : logs;

  return (
    <SuperAdminLayout>
      <div className="space-y-6">
        <div className="animate-fade-in">
          <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-1">Superadmin</p>
          <h1 className="text-2xl font-semibold text-foreground">Audit Logs</h1>
          <p className="text-sm text-muted-foreground">All superadmin actions — immutable history</p>
        </div>

        {/* Action filter pills */}
        <div className="flex items-center gap-2 flex-wrap animate-slide-up">
          {ACTION_FILTERS.map((f) => (
            <button
              key={f.value}
              onClick={() => { setActionFilter(f.value); setPage(1); }}
              className={`px-3 py-1.5 rounded-full text-xs font-semibold border transition-colors ${
                actionFilter === f.value
                  ? "bg-primary text-primary-foreground border-primary"
                  : "border-border text-muted-foreground hover:text-foreground hover:border-foreground/30"
              }`}
            >
              {f.label}
            </button>
          ))}
        </div>

        {/* Search */}
        <div className="relative max-w-xs">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search actor, action, details…"
            className="h-8 pl-8 pr-8 bg-secondary/50 text-sm"
          />
          {search && (
            <button onClick={() => setSearch("")} className="absolute right-3 top-1/2 -translate-y-1/2">
              <X className="h-3.5 w-3.5 text-muted-foreground hover:text-foreground" />
            </button>
          )}
        </div>

        {/* Table */}
        <div className="stat-card animate-slide-up">
          {isLoading ? (
            <div className="flex justify-center py-12">
              <Loader2 className="h-7 w-7 animate-spin text-muted-foreground" />
            </div>
          ) : filtered.length === 0 ? (
            <div className="py-16 text-center space-y-2">
              <ClipboardList className="h-10 w-10 mx-auto text-muted-foreground/20" />
              <p className="text-muted-foreground">No audit logs found</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border">
                    {["Time", "Actor", "Action", "Target", "Details"].map((h) => (
                      <th key={h} className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((log) => {
                    let details: Record<string, unknown> | null = null;
                    try { if (log.details) details = JSON.parse(log.details); } catch { /* raw string */ }

                    return (
                      <tr key={log.id} className="border-b border-border/30 hover:bg-accent/40 transition-colors">
                        <td className="py-3 px-4 text-xs font-mono text-muted-foreground whitespace-nowrap">{fmt(log.created_at)}</td>
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-2">
                            <div className="flex h-6 w-6 items-center justify-center rounded-full bg-secondary text-[9px] font-bold uppercase shrink-0">
                              {log.actor_username[0]}
                            </div>
                            <span className="text-sm font-medium text-foreground">{log.actor_username}</span>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <span className={`inline-flex items-center px-2 py-0.5 rounded-md text-xs font-mono font-semibold ${actionColor(log.action)}`}>
                            {log.action}
                          </span>
                        </td>
                        <td className="py-3 px-4 text-xs text-muted-foreground">
                          {log.target_type && (
                            <span className="font-medium text-foreground">{log.target_type}</span>
                          )}
                          {log.target_id && (
                            <span className="ml-1 font-mono opacity-60">{log.target_id.slice(0, 8)}…</span>
                          )}
                          {!log.target_type && "—"}
                        </td>
                        <td className="py-3 px-4 text-xs text-muted-foreground max-w-xs">
                          {details
                            ? Object.entries(details).map(([k, v]) => (
                                <span key={k} className="mr-3">
                                  <span className="text-muted-foreground/60">{k}: </span>
                                  <span className="text-foreground font-medium">{String(v)}</span>
                                </span>
                              ))
                            : log.details ?? "—"}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Pagination */}
        {!isLoading && totalPages > 1 && (
          <div className="flex items-center justify-between text-sm text-muted-foreground animate-slide-up">
            <span>{pagination.total} total entries</span>
            <div className="flex items-center gap-2">
              <Button
                variant="outline" size="icon" className="h-8 w-8"
                disabled={page === 1}
                onClick={() => setPage((p) => p - 1)}
              >
                <ChevronLeft className="h-4 w-4" />
              </Button>
              <span className="text-xs font-medium">Page {page} of {totalPages}</span>
              <Button
                variant="outline" size="icon" className="h-8 w-8"
                disabled={page >= totalPages}
                onClick={() => setPage((p) => p + 1)}
              >
                <ChevronRight className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}
      </div>
    </SuperAdminLayout>
  );
};

export default AuditLogsPage;
