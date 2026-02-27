import { useState } from "react";
import { Link } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { AlertTriangle, AlertCircle, Info, Download, Loader2, CheckCircle2, Trash2, RefreshCw } from "lucide-react";
import { dashboardApi } from "@/lib/api";
import { useToast } from "@/hooks/use-toast";
import {
    Breadcrumb,
    BreadcrumbItem,
    BreadcrumbLink,
    BreadcrumbList,
    BreadcrumbPage,
    BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";

const severityConfig = {
    critical: {
        icon: AlertTriangle,
        color: "text-red-500 bg-red-500/10",
        borderColor: "border-red-500/30",
    },
    warning: {
        icon: AlertCircle,
        color: "text-amber-500 bg-amber-500/10",
        borderColor: "border-amber-500/30",
    },
    info: {
        icon: Info,
        color: "text-blue-500 bg-blue-500/10",
        borderColor: "border-blue-500/30",
    },
};

const Alerts = () => {
    const queryClient = useQueryClient();
    const { toast } = useToast();

    const [startDate, setStartDate] = useState("");
    const [endDate, setEndDate] = useState("");
    const [severityFilter, setSeverityFilter] = useState<"critical" | "warning" | "info" | "">("");
    const [showResolved, setShowResolved] = useState(false);
    const [page, setPage] = useState(1);

    // Fetch alerts — auto-refresh every 30 s
    const { data, isLoading, isFetching, refetch } = useQuery({
        queryKey: ['alerts', startDate, endDate, severityFilter, showResolved, page],
        queryFn: () => dashboardApi.getAlerts({
            start_date: startDate || undefined,
            end_date: endDate || undefined,
            severity: severityFilter || undefined,
            resolved: showResolved ? undefined : false, // undefined = all, false = unresolved only
            page,
            limit: 50,
        }),
        refetchInterval: 30_000,
    });

    const alerts = data?.alerts ?? [];
    const pagination = data?.pagination;

    // Resolve mutation
    const resolveMutation = useMutation({
        mutationFn: dashboardApi.resolveAlert,
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['alerts'] });
            queryClient.invalidateQueries({ queryKey: ['unresolved-count'] });
            toast({ title: "Alert resolved" });
        },
        onError: () => toast({ title: "Failed to resolve alert", variant: "destructive" }),
    });

    // Delete mutation
    const deleteMutation = useMutation({
        mutationFn: dashboardApi.deleteAlert,
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['alerts'] });
            queryClient.invalidateQueries({ queryKey: ['unresolved-count'] });
            toast({ title: "Alert deleted" });
        },
        onError: () => toast({ title: "Failed to delete alert", variant: "destructive" }),
    });

    const handleClearFilters = () => {
        setStartDate("");
        setEndDate("");
        setSeverityFilter("");
        setShowResolved(false);
        setPage(1);
    };

    const handleExport = () => {
        const headers = ['ID', 'Title', 'Message', 'Machine', 'Severity', 'Resolved', 'Created At'];
        const rows = alerts.map(alert => [
            alert.id,
            alert.title,
            alert.message,
            alert.machine_name || 'N/A',
            alert.severity,
            alert.resolved ? 'Yes' : 'No',
            new Date(alert.created_at).toLocaleString(),
        ]);
        const csv = [
            headers.join(','),
            ...rows.map(row => row.map(cell => `"${cell}"`).join(',')),
        ].join('\n');

        const blob = new Blob([csv], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `alerts_${new Date().toISOString().split('T')[0]}.csv`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);
    };

    const criticalCount = alerts.filter(a => a.severity === 'critical' && !a.resolved).length;
    const warningCount = alerts.filter(a => a.severity === 'warning' && !a.resolved).length;
    const infoCount = alerts.filter(a => a.severity === 'info' && !a.resolved).length;

    if (isLoading) {
        return (
            <DashboardLayout>
                <div className="flex items-center justify-center h-96">
                    <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
                </div>
            </DashboardLayout>
        );
    }

    return (
        <DashboardLayout>
            <div className="space-y-6">
                <div className="animate-fade-in">
                    <div className="mb-4 -ml-1">
                        <Breadcrumb>
                            <BreadcrumbList>
                                <BreadcrumbItem>
                                    <BreadcrumbLink asChild><Link to="/dashboard">Home</Link></BreadcrumbLink>
                                </BreadcrumbItem>
                                <BreadcrumbSeparator />
                                <BreadcrumbItem>
                                    <BreadcrumbPage>System Alerts</BreadcrumbPage>
                                </BreadcrumbItem>
                            </BreadcrumbList>
                        </Breadcrumb>
                    </div>

                    <div className="flex items-center justify-between mb-6">
                        <div>
                            <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-1">Monitoring</p>
                            <h1 className="text-2xl font-semibold text-foreground">System Alerts</h1>
                            <p className="text-sm text-muted-foreground">Monitor and manage system alerts</p>
                        </div>
                        <div className="flex items-center gap-2">
                            {isFetching && !isLoading && (
                                <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />
                            )}
                            <Button variant="outline" size="sm" onClick={() => refetch()}>
                                <RefreshCw className="h-4 w-4 mr-2" />
                                Refresh
                            </Button>
                        </div>
                    </div>

                    {/* Filters */}
                    <div className="stat-card mb-6">
                        <div className="flex flex-col md:flex-row gap-4">
                            <div className="flex-1">
                                <label className="text-sm font-medium text-foreground mb-2 block">Start Date</label>
                                <Input type="date" value={startDate} onChange={(e) => { setStartDate(e.target.value); setPage(1); }} className="bg-secondary/50" />
                            </div>
                            <div className="flex-1">
                                <label className="text-sm font-medium text-foreground mb-2 block">End Date</label>
                                <Input type="date" value={endDate} onChange={(e) => { setEndDate(e.target.value); setPage(1); }} className="bg-secondary/50" />
                            </div>
                            <div className="flex-1">
                                <label className="text-sm font-medium text-foreground mb-2 block">Severity</label>
                                <select
                                    value={severityFilter}
                                    onChange={(e) => { setSeverityFilter(e.target.value as any); setPage(1); }}
                                    className="w-full h-10 px-3 rounded-md border border-input bg-secondary/50 text-foreground"
                                >
                                    <option value="">All Severities</option>
                                    <option value="critical">Critical</option>
                                    <option value="warning">Warning</option>
                                    <option value="info">Info</option>
                                </select>
                            </div>
                            <div className="flex-1">
                                <label className="text-sm font-medium text-foreground mb-2 block">Status</label>
                                <select
                                    value={showResolved ? "all" : "unresolved"}
                                    onChange={(e) => { setShowResolved(e.target.value === "all"); setPage(1); }}
                                    className="w-full h-10 px-3 rounded-md border border-input bg-secondary/50 text-foreground"
                                >
                                    <option value="unresolved">Unresolved Only</option>
                                    <option value="all">All Alerts</option>
                                </select>
                            </div>
                            <div className="flex items-end gap-2">
                                <Button variant="outline" onClick={handleClearFilters}>Clear</Button>
                                <Button variant="outline" onClick={handleExport} disabled={alerts.length === 0}>
                                    <Download className="h-4 w-4 mr-2" />
                                    Export
                                </Button>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Summary Stats */}
                <div className="grid gap-4 md:grid-cols-3 animate-fade-in">
                    <div className="stat-card">
                        <div className="flex items-center gap-3">
                            <div className="p-2 rounded-lg bg-red-500/10">
                                <AlertTriangle className="h-5 w-5 text-red-500" />
                            </div>
                            <div>
                                <p className="text-sm text-muted-foreground">Critical</p>
                                <p className="text-2xl font-bold text-foreground">{criticalCount}</p>
                            </div>
                        </div>
                    </div>
                    <div className="stat-card">
                        <div className="flex items-center gap-3">
                            <div className="p-2 rounded-lg bg-amber-500/10">
                                <AlertCircle className="h-5 w-5 text-amber-500" />
                            </div>
                            <div>
                                <p className="text-sm text-muted-foreground">Warning</p>
                                <p className="text-2xl font-bold text-foreground">{warningCount}</p>
                            </div>
                        </div>
                    </div>
                    <div className="stat-card">
                        <div className="flex items-center gap-3">
                            <div className="p-2 rounded-lg bg-blue-500/10">
                                <Info className="h-5 w-5 text-blue-500" />
                            </div>
                            <div>
                                <p className="text-sm text-muted-foreground">Info</p>
                                <p className="text-2xl font-bold text-foreground">{infoCount}</p>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Alerts List */}
                <div className="stat-card animate-slide-up">
                    <div className="space-y-3">
                        {alerts.length === 0 ? (
                            <div className="text-center py-12 text-muted-foreground">
                                <CheckCircle2 className="h-12 w-12 mx-auto mb-4 opacity-40 text-emerald-500" />
                                <p className="font-medium">No alerts found</p>
                                <p className="text-sm mt-1">All systems are running normally</p>
                            </div>
                        ) : (
                            alerts.map((alert) => {
                                const config = severityConfig[alert.severity] ?? severityConfig.info;
                                const Icon = config.icon;
                                const isMutating =
                                    resolveMutation.isPending || deleteMutation.isPending;

                                return (
                                    <div
                                        key={alert.id}
                                        className={`flex items-start gap-4 p-4 rounded-lg border transition-colors ${
                                            alert.resolved
                                                ? "border-border/30 opacity-60"
                                                : config.borderColor
                                        }`}
                                    >
                                        <div className={`p-2 rounded-lg flex-shrink-0 ${alert.resolved ? "bg-muted" : config.color}`}>
                                            {alert.resolved
                                                ? <CheckCircle2 className="h-5 w-5 text-muted-foreground" />
                                                : <Icon className="h-5 w-5" />
                                            }
                                        </div>

                                        <div className="flex-1 min-w-0">
                                            <div className="flex items-start justify-between gap-4">
                                                <div>
                                                    <div className="flex items-center gap-2 flex-wrap">
                                                        <h3 className="font-semibold text-foreground text-sm">{alert.title}</h3>
                                                        <span className={`px-2 py-0.5 rounded text-xs font-medium ${
                                                            alert.resolved ? "bg-muted text-muted-foreground" : config.color
                                                        }`}>
                                                            {alert.resolved ? "RESOLVED" : alert.severity.toUpperCase()}
                                                        </span>
                                                    </div>
                                                    <p className="text-sm text-muted-foreground mt-0.5">{alert.message}</p>
                                                    {alert.machine_name && (
                                                        <p className="text-xs text-muted-foreground mt-1">
                                                            Machine: <span className="font-medium text-foreground">{alert.machine_name}</span>
                                                        </p>
                                                    )}
                                                    {alert.resolved && alert.resolved_at && (
                                                        <p className="text-xs text-emerald-500 mt-1">
                                                            Resolved {new Date(alert.resolved_at).toLocaleString()}
                                                        </p>
                                                    )}
                                                </div>
                                                <div className="flex flex-col items-end gap-2 flex-shrink-0">
                                                    <p className="text-xs text-muted-foreground whitespace-nowrap">
                                                        {new Date(alert.created_at).toLocaleString()}
                                                    </p>
                                                    <div className="flex gap-1">
                                                        {!alert.resolved && (
                                                            <Button
                                                                size="sm"
                                                                variant="outline"
                                                                className="h-7 px-2 text-xs text-emerald-500 border-emerald-500/30 hover:bg-emerald-500/10"
                                                                disabled={isMutating}
                                                                onClick={() => resolveMutation.mutate(alert.id)}
                                                            >
                                                                <CheckCircle2 className="h-3 w-3 mr-1" />
                                                                Resolve
                                                            </Button>
                                                        )}
                                                        <Button
                                                            size="sm"
                                                            variant="ghost"
                                                            className="h-7 w-7 p-0 text-muted-foreground hover:text-destructive"
                                                            disabled={isMutating}
                                                            onClick={() => deleteMutation.mutate(alert.id)}
                                                        >
                                                            <Trash2 className="h-3.5 w-3.5" />
                                                        </Button>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })
                        )}
                    </div>

                    {/* Pagination */}
                    {pagination && pagination.total_pages > 1 && (
                        <div className="flex items-center justify-between mt-6 pt-4 border-t border-border">
                            <p className="text-sm text-muted-foreground">
                                Page {pagination.current_page} of {pagination.total_pages} ({pagination.total_items} total)
                            </p>
                            <div className="flex gap-2">
                                <Button
                                    variant="outline"
                                    size="sm"
                                    disabled={page <= 1}
                                    onClick={() => setPage(p => p - 1)}
                                >
                                    Previous
                                </Button>
                                <Button
                                    variant="outline"
                                    size="sm"
                                    disabled={page >= pagination.total_pages}
                                    onClick={() => setPage(p => p + 1)}
                                >
                                    Next
                                </Button>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </DashboardLayout>
    );
};

export default Alerts;
