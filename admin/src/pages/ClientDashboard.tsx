import { useParams, useNavigate, useLocation, Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import DashboardLayout from "@/components/layout/DashboardLayout";
import StatCard from "@/components/dashboard/StatCard";
import ActivityLog, { LogEntry } from "@/components/dashboard/ActivityLog";
import { Button } from "@/components/ui/button";
import { ArrowLeft, CreditCard, DollarSign, Users, TrendingUp, Building2, Edit, Trash2, History, Loader2, Receipt } from "lucide-react";
import { machinesApi, servicesApi, logsApi } from "@/lib/api";
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";

const ClientDashboard = () => {
  const { id } = useParams();
  const navigate = useNavigate();

  // Fetch machine data — poll every 30 s so status changes appear automatically
  const { data: machine, isLoading: machineLoading } = useQuery({
    queryKey: ['machine', id],
    queryFn: () => machinesApi.getById(id!),
    enabled: !!id,
    refetchInterval: 30_000,
  });

  // Fetch services
  const { data: services = [] } = useQuery({
    queryKey: ['services', id],
    queryFn: () => servicesApi.getByMachine(id!),
    enabled: !!id,
  });

  // Fetch recent logs
  const { data: response } = useQuery({
    queryKey: ['logs', id, 'recent'],
    queryFn: () => logsApi.getByMachine(id!, { limit: 10 }),
    enabled: !!id,
  });

  const logs = response?.logs || [];

  if (machineLoading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center h-96">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      </DashboardLayout>
    );
  }

  if (!machine) {
    return (
      <DashboardLayout>
        <div className="flex flex-col items-center justify-center py-20">
          <p className="text-lg text-muted-foreground mb-4">Machine not found</p>
          <Button variant="outline" onClick={() => navigate("/clients")}>
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back to Machines
          </Button>
        </div>
      </DashboardLayout>
    );
  }

  // Transform logs to ActivityLog format
  const activityLogs: LogEntry[] = logs.map(log => ({
    id: log.id,
    action: log.action,
    details: log.details,
    timestamp: new Date(log.created_at).toLocaleString(),
    type: log.type as any,
  }));

  const totalCollection = Number(machine.online_collection) + Number(machine.offline_collection);

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Header */}
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
                  <BreadcrumbPage>{machine.name}</BreadcrumbPage>
                </BreadcrumbItem>
              </BreadcrumbList>
            </Breadcrumb>
          </div>

          <div className="flex items-center gap-4">
            <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-primary/10">
              <Building2 className="h-8 w-8 text-primary" />
            </div>
            <div className="flex-1">
              <h1 className="text-3xl font-bold text-foreground">{machine.name}</h1>
              <p className="text-muted-foreground">{machine.location}</p>
            </div>
            <div className="flex items-center gap-2">
              <span className={`px-3 py-1.5 rounded-full text-sm font-medium ${machine.status === 'online'
                ? 'bg-emerald-500/10 text-emerald-500'
                : machine.status === 'offline'
                  ? 'bg-red-500/10 text-red-500'
                  : 'bg-amber-500/10 text-amber-500'
                }`}>
                {machine.status.toUpperCase()}
              </span>
              <span className="text-sm text-muted-foreground">
                Last sync: {new Date(machine.last_sync).toLocaleString()}
              </span>
            </div>
          </div>
        </div>

        {/* Stats */}
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4 animate-slide-up">
          <StatCard
            title="Total Collection"
            value={`₹${totalCollection.toLocaleString()}`}
            icon={DollarSign}
          />
          <StatCard
            title="Online Payments"
            value={`₹${Number(machine.online_collection).toLocaleString()}`}
            icon={CreditCard}
          />
          <StatCard
            title="Offline Payments"
            value={`₹${Number(machine.offline_collection).toLocaleString()}`}
            icon={DollarSign}
          />
          <StatCard
            title="Active Services"
            value={services.filter(s => s.status === 'active').length.toString()}
            icon={Users}
            trend={{ value: 5.4, isPositive: true }}
          />
        </div>

        {/* Quick Actions */}
        <div className="grid gap-6 md:grid-cols-2 animate-slide-up" style={{ animationDelay: "0.1s" }}>
          <div className="stat-card">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-foreground">Service Catalog</h3>
              <Button variant="outline" size="sm" onClick={() => navigate(`/clients/${id}/catalog`)}>
                View All
              </Button>
            </div>
            <div className="space-y-3">
              {services.slice(0, 3).map((service) => (
                <div key={service.id} className="flex items-center justify-between p-3 rounded-lg bg-secondary/30 hover:bg-secondary/50 transition-colors">
                  <div>
                    <p className="font-medium text-foreground">{service.name}</p>
                    <p className="text-sm text-muted-foreground">₹{service.price}</p>
                  </div>
                  <span className={`px-2 py-1 rounded text-xs font-medium ${service.status === 'active'
                    ? 'bg-emerald-500/10 text-emerald-500'
                    : 'bg-muted text-muted-foreground'
                    }`}>
                    {service.status}
                  </span>
                </div>
              ))}
              {services.length === 0 && (
                <p className="text-center text-muted-foreground py-4">No services configured</p>
              )}
            </div>
          </div>

          <div className="stat-card">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-foreground">Recent Activity</h3>
              <Button variant="outline" size="sm" onClick={() => navigate(`/clients/${id}/logs`)}>
                View All
              </Button>
            </div>
            <div className="space-y-3">
              {activityLogs.slice(0, 3).map((log) => (
                <div key={log.id} className="flex items-center justify-between p-3 rounded-lg bg-secondary/30 hover:bg-secondary/50 transition-colors">
                  <div>
                    <p className="font-medium text-foreground">{log.action}</p>
                    <p className="text-sm text-muted-foreground">{log.timestamp}</p>
                  </div>
                  <span className={`px-2 py-1 rounded text-xs font-medium ${log.type === 'login' ? 'bg-emerald-500/10 text-emerald-500' :
                    log.type === 'client' ? 'bg-blue-500/10 text-blue-500' :
                      'bg-amber-500/10 text-amber-500'
                    }`}>
                    {log.type}
                  </span>
                </div>
              ))}
              {activityLogs.length === 0 && (
                <p className="text-center text-muted-foreground py-4">No recent activity</p>
              )}
            </div>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="grid gap-4 md:grid-cols-4 animate-slide-up" style={{ animationDelay: "0.2s" }}>
          <Button
            variant="outline"
            className="h-auto py-4 flex flex-col items-center gap-2"
            onClick={() => navigate(`/clients/${id}/catalog`)}
          >
            <Edit className="h-5 w-5" />
            <span>Manage Catalog</span>
          </Button>
          <Button
            variant="outline"
            className="h-auto py-4 flex flex-col items-center gap-2"
            onClick={() => navigate(`/clients/${id}/payments`)}
          >
            <CreditCard className="h-5 w-5" />
            <span>View Payments</span>
          </Button>
          <Button
            variant="outline"
            className="h-auto py-4 flex flex-col items-center gap-2"
            onClick={() => navigate(`/clients/${id}/catalog-logs`)}
          >
            <History className="h-5 w-5" />
            <span>Catalog History</span>
          </Button>
          <Button
            variant="outline"
            className="h-auto py-4 flex flex-col items-center gap-2"
            onClick={() => navigate(`/clients/${id}/bill-settings`)}
          >
            <Receipt className="h-5 w-5" />
            <span>Bill Settings</span>
          </Button>
        </div>
      </div>
    </DashboardLayout>
  );
};

export default ClientDashboard;
