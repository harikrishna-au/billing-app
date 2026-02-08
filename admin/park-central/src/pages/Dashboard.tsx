import DashboardLayout from "@/components/layout/DashboardLayout";
import StatCard from "@/components/dashboard/StatCard";
import RevenueChart from "@/components/dashboard/RevenueChart";
import SystemAlerts from "@/components/dashboard/SystemAlerts";
import { Building2, Activity, DollarSign, TrendingUp, Loader2 } from "lucide-react";
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

  // Show loading state while initial data is being fetched
  if (statsLoading && !stats) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center h-96">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Header */}
        <div className="animate-fade-in">
          <h1 className="text-3xl font-semibold text-foreground">Dashboard</h1>
          <p className="mt-1 text-muted-foreground">
            Welcome back! Here's your billing overview.
          </p>
        </div>

        {/* Stats Grid */}
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          <StatCard
            title="Total Machines"
            value={stats?.totalMachines || 0}
            subtitle="Registered terminals"
            icon={Building2}
          />
          <StatCard
            title="Online Machines"
            value={stats?.onlineMachines || 0}
            subtitle="Currently syncing"
            icon={Activity}
          />
          <StatCard
            title="Today's Collection"
            value={`₹${(stats?.todayCollection || 0).toLocaleString('en-IN')}`}
            subtitle="All terminals combined"
            icon={DollarSign}
          />
          <StatCard
            title="Monthly Collection"
            value={`₹${((stats?.monthlyCollection || 0) / 1000).toFixed(1)}k`}
            subtitle={new Date().toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
            icon={TrendingUp}
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
