import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import SuperAdminLayout from "@/components/layout/SuperAdminLayout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { useToast } from "@/hooks/use-toast";
import { superadminApi, type UpiRequest } from "@/lib/api/superadmin";
import { CheckCircle, XCircle, Clock, ArrowRight, Loader2 } from "lucide-react";

function fmt(iso: string | null) {
  if (!iso) return "—";
  return new Date(iso).toLocaleString("en-IN", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" });
}

const FILTERS = ["pending", "approved", "rejected", ""] as const;

const UpiApprovalsPage = () => {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [filter, setFilter] = useState<string>("pending");
  const [rejectTarget, setRejectTarget] = useState<UpiRequest | null>(null);
  const [rejectNote, setRejectNote] = useState("");

  const { data: requests = [], isLoading } = useQuery({
    queryKey: ["sa-upi-requests", filter],
    queryFn: () => superadminApi.listUpiRequests(filter || undefined),
    refetchInterval: 20_000,
  });

  const pendingCount = filter !== "pending"
    ? 0
    : requests.filter((r) => r.status === "pending").length;

  const approveMutation = useMutation({
    mutationFn: superadminApi.approveUpiRequest,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["sa-upi-requests"] });
      qc.invalidateQueries({ queryKey: ["sa-pending-count"] });
      toast({ title: "UPI change approved and applied to machine" });
    },
    onError: (e: any) =>
      toast({ title: "Error", description: e?.response?.data?.detail || "Failed", variant: "destructive" }),
  });

  const rejectMutation = useMutation({
    mutationFn: ({ id, note }: { id: string; note: string }) =>
      superadminApi.rejectUpiRequest(id, note),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["sa-upi-requests"] });
      qc.invalidateQueries({ queryKey: ["sa-pending-count"] });
      toast({ title: "Request rejected" });
      setRejectTarget(null);
      setRejectNote("");
    },
    onError: (e: any) =>
      toast({ title: "Error", description: e?.response?.data?.detail || "Failed", variant: "destructive" }),
  });

  return (
    <SuperAdminLayout>
      <div className="space-y-6">
        <div className="animate-fade-in">
          <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-1">Superadmin</p>
          <h1 className="text-2xl font-semibold text-foreground">UPI Approvals</h1>
          <p className="text-sm text-muted-foreground">Review and approve UPI ID change requests from admins</p>
        </div>

        {/* Filters */}
        <div className="flex items-center gap-2">
          {FILTERS.map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-3 py-1.5 rounded-full text-xs font-semibold border transition-colors ${
                filter === f
                  ? "bg-primary text-primary-foreground border-primary"
                  : "border-border text-muted-foreground hover:text-foreground hover:border-foreground/30"
              }`}
            >
              {f === "" ? "All" : f.charAt(0).toUpperCase() + f.slice(1)}
              {f === "pending" && pendingCount > 0 && (
                <span className="ml-1.5 bg-amber-500 text-white rounded-full px-1.5 text-[9px] font-bold">{pendingCount}</span>
              )}
            </button>
          ))}
        </div>

        {/* List */}
        {isLoading ? (
          <div className="flex justify-center py-16">
            <Loader2 className="h-7 w-7 animate-spin text-muted-foreground" />
          </div>
        ) : requests.length === 0 ? (
          <div className="stat-card text-center py-16 space-y-3">
            <Clock className="h-10 w-10 mx-auto text-muted-foreground/20" />
            <p className="text-muted-foreground">No {filter} UPI requests</p>
          </div>
        ) : (
          <div className="space-y-3 animate-slide-up">
            {requests.map((r) => (
              <div key={r.id} className="stat-card p-5">
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1 min-w-0 space-y-2">
                    {/* Top row */}
                    <div className="flex items-center gap-2 flex-wrap">
                      <Badge className={
                        r.status === "pending"  ? "bg-amber-500/10 text-amber-500 border-amber-500/20 text-xs" :
                        r.status === "approved" ? "bg-emerald-500/10 text-emerald-500 border-emerald-500/20 text-xs" :
                                                  "bg-red-500/10 text-red-500 border-red-500/20 text-xs"
                      }>
                        {r.status.toUpperCase()}
                      </Badge>
                      <span className="text-sm font-semibold text-foreground">{r.machine_name}</span>
                      <span className="text-xs text-muted-foreground">requested by <strong>{r.requested_by}</strong></span>
                    </div>

                    {/* UPI change */}
                    <div className="flex items-center gap-2 font-mono text-sm bg-secondary/40 rounded-lg px-3 py-2 w-fit">
                      <span className="text-muted-foreground">{r.old_upi_id || <em className="not-italic opacity-40">not set</em>}</span>
                      <ArrowRight className="h-3 w-3 text-muted-foreground shrink-0" />
                      <span className="text-primary font-semibold">{r.new_upi_id}</span>
                    </div>

                    <div className="flex items-center gap-3 text-xs text-muted-foreground">
                      <span>Requested {fmt(r.created_at)}</span>
                      {r.resolved_at && <span>· Resolved {fmt(r.resolved_at)}</span>}
                    </div>

                    {r.superadmin_note && (
                      <p className="text-xs text-muted-foreground italic border-l-2 border-border pl-2">
                        {r.superadmin_note}
                      </p>
                    )}
                  </div>

                  {r.status === "pending" && (
                    <div className="flex flex-col gap-2 shrink-0">
                      <Button
                        size="sm" variant="glow" className="h-8 gap-1.5"
                        disabled={approveMutation.isPending || rejectMutation.isPending}
                        onClick={() => approveMutation.mutate(r.id)}
                      >
                        <CheckCircle className="h-3.5 w-3.5" /> Approve
                      </Button>
                      <Button
                        size="sm" variant="outline"
                        className="h-8 gap-1.5 border-red-500/30 text-red-500 hover:bg-red-500/10"
                        disabled={approveMutation.isPending || rejectMutation.isPending}
                        onClick={() => { setRejectTarget(r); setRejectNote(""); }}
                      >
                        <XCircle className="h-3.5 w-3.5" /> Reject
                      </Button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Reject dialog */}
      <Dialog open={!!rejectTarget} onOpenChange={(o) => !o && setRejectTarget(null)}>
        <DialogContent className="bg-card border-border">
          <DialogHeader>
            <DialogTitle>Reject UPI Request</DialogTitle>
            <DialogDescription>
              Rejecting <span className="font-mono text-primary">{rejectTarget?.new_upi_id}</span> for <strong>{rejectTarget?.machine_name}</strong>
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
              <Button variant="outline" onClick={() => setRejectTarget(null)}>Cancel</Button>
              <Button
                variant="destructive"
                disabled={rejectMutation.isPending}
                onClick={() => rejectMutation.mutate({ id: rejectTarget!.id, note: rejectNote })}
              >
                {rejectMutation.isPending ? "Rejecting..." : "Confirm Reject"}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </SuperAdminLayout>
  );
};

export default UpiApprovalsPage;
