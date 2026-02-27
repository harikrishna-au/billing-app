import { useState } from "react";
import { useNavigate, useParams, Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ArrowLeft, Download, Filter, Building2, LogIn, Settings, Shield, User, Loader2 } from "lucide-react";
import { logsApi, machinesApi, analyticsApi } from "@/lib/api";
import {
    Breadcrumb,
    BreadcrumbItem,
    BreadcrumbLink,
    BreadcrumbList,
    BreadcrumbPage,
    BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";

const iconMap: Record<string, any> = {
    login: LogIn,
    client: Building2,
    config: Settings,
    manager: User,
    system: Shield,
    create: Building2,
    update: Settings,
    delete: Shield,
};

const colorMap: Record<string, string> = {
    login: "text-chart-1 bg-chart-1/10",
    client: "text-chart-2 bg-chart-2/10",
    config: "text-chart-3 bg-chart-3/10",
    manager: "text-chart-4 bg-chart-4/10",
    system: "text-chart-5 bg-chart-5/10",
    create: "text-chart-2 bg-chart-2/10",
    update: "text-chart-3 bg-chart-3/10",
    delete: "text-chart-5 bg-chart-5/10",
};

const MachineLogs = () => {
    const navigate = useNavigate();
    const { id } = useParams();
    const [dateFilter, setDateFilter] = useState("");
    const [isExporting, setIsExporting] = useState(false);

    const handleExport = async () => {
        setIsExporting(true);
        try {
            const params: Record<string, string> = { machine_id: id! };
            if (dateFilter) {
                params.start_date = new Date(dateFilter).toISOString();
                params.end_date = new Date(dateFilter + 'T23:59:59').toISOString();
            }
            const blob = await analyticsApi.exportData('logs', params);
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `logs_${id}${dateFilter ? '_' + dateFilter : ''}.csv`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        } catch (e) {
            console.error('Export failed', e);
        } finally {
            setIsExporting(false);
        }
    };

    // Fetch machine data
    const { data: machine } = useQuery({
        queryKey: ['machine', id],
        queryFn: () => machinesApi.getById(id!),
        enabled: !!id,
    });

    // Fetch logs
    const { data: response, isLoading } = useQuery({
        queryKey: ['logs', id],
        queryFn: () => logsApi.getByMachine(id!),
        enabled: !!id,
    });

    const logs = response?.logs || [];

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
                                    <BreadcrumbLink asChild>
                                        <Link to="/clients">Billing Machines</Link>
                                    </BreadcrumbLink>
                                </BreadcrumbItem>
                                <BreadcrumbSeparator />
                                <BreadcrumbItem>
                                    <BreadcrumbLink asChild>
                                        <Link to={`/clients/${id}`}>{machine?.name || 'Unknown Machine'}</Link>
                                    </BreadcrumbLink>
                                </BreadcrumbItem>
                                <BreadcrumbSeparator />
                                <BreadcrumbItem>
                                    <BreadcrumbPage>Activity Logs</BreadcrumbPage>
                                </BreadcrumbItem>
                            </BreadcrumbList>
                        </Breadcrumb>
                    </div>

                    <div className="flex items-center justify-between">
                        <div>
                            <h1 className="text-2xl font-bold text-foreground">Activity Logs</h1>
                            <p className="text-muted-foreground">Machine ID: {id}</p>
                        </div>

                        <div className="flex items-center gap-3">
                            <div className="relative">
                                <Input
                                    type="date"
                                    value={dateFilter}
                                    onChange={(e) => setDateFilter(e.target.value)}
                                    className="w-48 bg-secondary/50"
                                    placeholder="Filter by date"
                                />
                                <Filter className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground pointer-events-none" />
                            </div>
                            <Button variant="outline" size="sm" onClick={handleExport} disabled={isExporting}>
                                {isExporting
                                    ? <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                                    : <Download className="h-4 w-4 mr-2" />}
                                Export
                            </Button>
                        </div>
                    </div>
                </div>

                <div className="stat-card animate-slide-up">
                    <div className="space-y-4">
                        {logs.length === 0 ? (
                            <div className="text-center py-12 text-muted-foreground">
                                No activity logs found
                            </div>
                        ) : (
                            logs.map((log) => {
                                const Icon = iconMap[log.type] || Shield;
                                const colorClass = colorMap[log.type] || colorMap.system;

                                return (
                                    <div
                                        key={log.id}
                                        className="flex items-start gap-4 p-4 rounded-lg border border-border/50 hover:bg-accent/30 transition-colors"
                                    >
                                        <div className={`p-2 rounded-lg ${colorClass}`}>
                                            <Icon className="h-5 w-5" />
                                        </div>

                                        <div className="flex-1">
                                            <div className="flex items-start justify-between">
                                                <div>
                                                    <h3 className="font-semibold text-foreground">{log.action}</h3>
                                                    <p className="text-sm text-muted-foreground mt-1">{log.details}</p>
                                                </div>
                                                <span className="text-xs text-muted-foreground whitespace-nowrap">
                                                    {new Date(log.created_at).toLocaleString()}
                                                </span>
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

export default MachineLogs;
