import DashboardLayout from "@/components/layout/DashboardLayout";
import StatCard from "@/components/dashboard/StatCard";
import RevenueChart from "@/components/dashboard/RevenueChart";
import SystemAlerts from "@/components/dashboard/SystemAlerts";
import { Building2, Activity, DollarSign, TrendingUp } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { dashboardApi } from "@/lib/api";

const Dashboard = () => {
  // Fetch dashboard stats
  const { data: stats, isLoading: statsLoading } = useQuery({
    queryKey: ['dashboardStats'],
    queryFn: () => dashboardApi.getDashboardStats(),
    refetchInterval: 30000, // Refetch every 30 seconds
  });

  // Fetch weekly revenue data
  const { data: revenueData, isLoading: revenueLoading } = useQuery({
    queryKey: ['weeklyRevenue'],
    queryFn: () => dashboardApi.getWeeklyRevenue(),
    refetchInterval: 60000, // Refetch every minute
  });

  // Fetch system alerts
  const { data: alerts, isLoading: alertsLoading } = useQuery({
    queryKey: ['systemAlerts'],
    queryFn: () => dashboardApi.getSystemAlerts(),
    refetchInterval: 30000, // Refetch every 30 seconds
  });

  // Show a skeleton that mirrors the real layout while data loads.
  if (statsLoading && !stats) {
    return (
      <DashboardLayout>
        <div className="space-y-8">
          <div className="space-y-2">
            <div className="skeleton h-3 w-20" />
            <div className="skeleton h-7 w-44" />
            <div className="skeleton h-4 w-64" />
          </div>
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="stat-card">
                <div className="skeleton h-3 w-24" />
                <div className="skeleton mt-3 h-8 w-28" />
                <div className="skeleton mt-2 h-3 w-20" />
              </div>
            ))}
          </div>
          <div className="grid gap-6 lg:grid-cols-2">
            <div className="stat-card h-80">
              <div className="skeleton h-full w-full" />
            </div>
            <div className="stat-card h-80">
              <div className="skeleton h-full w-full" />
            </div>
          </div>
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Header */}
        <div className="animate-fade-in">
          <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-1">Overview</p>
          <h1 className="text-2xl font-semibold text-foreground">Dashboard</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Here's your Blaze overview for today.
          </p>
        </div>

        {/* Stats Grid */}
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          <StatCard
            title="Total Machines"
            value={stats?.totalMachines || 0}
            subtitle="Registered terminals"
            icon={Building2}
            delay={0}
          />
          <StatCard
            title="Online Machines"
            value={stats?.onlineMachines || 0}
            subtitle="Currently syncing"
            icon={Activity}
            delay={60}
          />
          <StatCard
            title="Today's Collection"
            value={`₹${(stats?.todayCollection || 0).toLocaleString('en-IN')}`}
            subtitle="All terminals combined"
            icon={DollarSign}
            delay={120}
          />
          <StatCard
            title="Monthly Collection"
            value={`₹${((stats?.monthlyCollection || 0) / 1000).toFixed(1)}k`}
            subtitle={new Date().toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
            icon={TrendingUp}
            delay={180}
          />
        </div>

        {/* Charts Row */}
        <div className="grid gap-6 lg:grid-cols-2">
          <RevenueChart data={revenueData} />
          <SystemAlerts alerts={alerts} />
        </div>
      </div>
    </DashboardLayout>
  );
};

export default Dashboard;
