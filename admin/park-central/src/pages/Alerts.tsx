import { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { AlertTriangle, AlertCircle, Info, Filter, Download, Loader2 } from "lucide-react";
import { dashboardApi } from "@/lib/api";
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
        borderColor: "border-red-500/50",
    },
    warning: {
        icon: AlertCircle,
        color: "text-amber-500 bg-amber-500/10",
        borderColor: "border-amber-500/50",
    },
    info: {
        icon: Info,
        color: "text-blue-500 bg-blue-500/10",
        borderColor: "border-blue-500/50",
    },
};

const Alerts = () => {
    const navigate = useNavigate();
    const [startDate, setStartDate] = useState("");
    const [endDate, setEndDate] = useState("");
    const [severityFilter, setSeverityFilter] = useState<"critical" | "warning" | "info" | "">("");

    // Fetch alerts
    const { data: alerts = [], isLoading } = useQuery({
        queryKey: ['alerts', startDate, endDate, severityFilter],
        queryFn: () => dashboardApi.getAlerts({
            start_date: startDate || undefined,
            end_date: endDate || undefined,
            severity: severityFilter || undefined,
        }),
    });

    const handleClearFilters = () => {
        setStartDate("");
        setEndDate("");
        setSeverityFilter("");
    };

    const handleExport = async () => {
        try {
            // Create CSV content from alerts
            const headers = ['ID', 'Title', 'Message', 'Machine', 'Severity', 'Created At'];
            const rows = alerts.map(alert => [
                alert.id,
                alert.title,
                alert.message,
                alert.machine_name || 'N/A',
                alert.severity,
                new Date(alert.created_at).toLocaleString()
            ]);

            const csvContent = [
                headers.join(','),
                ...rows.map(row => row.map(cell => `"${cell}"`).join(','))
            ].join('\n');

            // Create and download file
            const blob = new Blob([csvContent], { type: 'text/csv' });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `alerts_${new Date().toISOString().split('T')[0]}.csv`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            window.URL.revokeObjectURL(url);
        } catch (error) {
            console.error('Export failed:', error);
        }
    };

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
                                    <BreadcrumbLink asChild>
                                        <Link to="/dashboard">Home</Link>
                                    </BreadcrumbLink>
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
                            <h1 className="text-2xl font-bold text-foreground">System Alerts</h1>
                            <p className="text-muted-foreground">Monitor and manage system alerts</p>
                        </div>
                    </div>

                    {/* Filters */}
                    <div className="stat-card mb-6">
                        <div className="flex flex-col md:flex-row gap-4">
                            <div className="flex-1">
                                <label className="text-sm font-medium text-foreground mb-2 block">
                                    Start Date
                                </label>
                                <Input
                                    type="date"
                                    value={startDate}
                                    onChange={(e) => setStartDate(e.target.value)}
                                    className="bg-secondary/50"
                                />
                            </div>
                            <div className="flex-1">
                                <label className="text-sm font-medium text-foreground mb-2 block">
                                    End Date
                                </label>
                                <Input
                                    type="date"
                                    value={endDate}
                                    onChange={(e) => setEndDate(e.target.value)}
                                    className="bg-secondary/50"
                                />
                            </div>
                            <div className="flex-1">
                                <label className="text-sm font-medium text-foreground mb-2 block">
                                    Severity
                                </label>
                                <select
                                    value={severityFilter}
                                    onChange={(e) => setSeverityFilter(e.target.value as any)}
                                    className="w-full h-10 px-3 rounded-md border border-input bg-secondary/50 text-foreground"
                                >
                                    <option value="">All Severities</option>
                                    <option value="critical">Critical</option>
                                    <option value="warning">Warning</option>
                                    <option value="info">Info</option>
                                </select>
                            </div>
                            <div className="flex items-end gap-2">
                                <Button variant="outline" onClick={handleClearFilters}>
                                    Clear
                                </Button>
                                <Button variant="outline" onClick={handleExport}>
                                    <Download className="h-4 w-4 mr-2" />
                                    Export
                                </Button>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Summary Stats */}
                {alerts.length > 0 && (
                    <div className="grid gap-4 md:grid-cols-3 animate-fade-in">
                        <div className="stat-card">
                            <div className="flex items-center gap-3">
                                <div className="p-2 rounded-lg bg-red-500/10">
                                    <AlertTriangle className="h-5 w-5 text-red-500" />
                                </div>
                                <div>
                                    <p className="text-sm text-muted-foreground">Critical</p>
                                    <p className="text-2xl font-bold text-foreground">
                                        {alerts.filter(a => a.severity === 'critical').length}
                                    </p>
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
                                    <p className="text-2xl font-bold text-foreground">
                                        {alerts.filter(a => a.severity === 'warning').length}
                                    </p>
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
                                    <p className="text-2xl font-bold text-foreground">
                                        {alerts.filter(a => a.severity === 'info').length}
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>
                )}

                {/* Alerts List */}
                <div className="stat-card animate-slide-up">
                    <div className="space-y-4">
                        {alerts.length === 0 ? (
                            <div className="text-center py-12 text-muted-foreground">
                                <Info className="h-12 w-12 mx-auto mb-4 opacity-50" />
                                <p>No alerts found</p>
                            </div>
                        ) : (
                            alerts.map((alert) => {
                                const config = severityConfig[alert.severity];
                                const Icon = config.icon;

                                return (
                                    <div
                                        key={alert.id}
                                        className={`flex items-start gap-4 p-4 rounded-lg border ${config.borderColor} hover:bg-accent/30 transition-colors`}
                                    >
                                        <div className={`p-2 rounded-lg ${config.color}`}>
                                            <Icon className="h-5 w-5" />
                                        </div>

                                        <div className="flex-1">
                                            <div className="flex items-start justify-between">
                                                <div>
                                                    <h3 className="font-semibold text-foreground">{alert.title}</h3>
                                                    <p className="text-sm text-muted-foreground mt-1">
                                                        {alert.message}
                                                    </p>
                                                    {alert.machine_name && (
                                                        <p className="text-xs text-muted-foreground mt-2">
                                                            Machine: <span className="font-medium">{alert.machine_name}</span>
                                                        </p>
                                                    )}
                                                </div>
                                                <div className="text-right">
                                                    <span
                                                        className={`px-2 py-1 rounded text-xs font-medium ${config.color}`}
                                                    >
                                                        {alert.severity.toUpperCase()}
                                                    </span>
                                                    <p className="text-xs text-muted-foreground mt-2 whitespace-nowrap">
                                                        {new Date(alert.created_at).toLocaleString()}
                                                    </p>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })
                        )}
                    </div>
                </div>
            </div>
        </DashboardLayout>
    );
};

export default Alerts;
