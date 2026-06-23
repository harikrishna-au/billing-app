import { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { LayoutDashboard, Monitor, AlertTriangle, LogOut, ShieldCheck, Users, CreditCard, ClipboardList } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { dashboardApi } from "@/lib/api";
import { superadminApi } from "@/lib/api/superadmin";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";

const Sidebar = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const [showSignOutDialog, setShowSignOutDialog] = useState(false);

  const storedUser = (() => { try { return JSON.parse(localStorage.getItem("user") || "{}"); } catch { return {}; } })();
  const isSuperAdmin = storedUser?.role === "superadmin";

  const handleLogout = () => {
    localStorage.removeItem("adminSession");
    localStorage.removeItem("access_token");
    localStorage.removeItem("refresh_token");
    localStorage.removeItem("user");
    navigate("/login");
  };

  // Admin: poll unresolved alert count
  const { data: unresolvedCount = 0 } = useQuery({
    queryKey: ["unresolved-count"],
    queryFn: dashboardApi.getUnresolvedCount,
    refetchInterval: 60_000,
    retry: false,
    enabled: !isSuperAdmin,
  });

  // Superadmin: poll pending UPI count
  const { data: pendingUpiCount = 0 } = useQuery({
    queryKey: ["sa-pending-count"],
    queryFn: async () => {
      const reqs = await superadminApi.listUpiRequests("pending");
      return reqs.length;
    },
    refetchInterval: 30_000,
    enabled: isSuperAdmin,
  });

  const adminNavItems = [
    { icon: LayoutDashboard, label: "Dashboard",     path: "/dashboard" },
    { icon: Monitor,         label: "Blaze Machines", path: "/clients" },
    { icon: AlertTriangle,   label: "System Alerts",  path: "/alerts", badge: unresolvedCount },
  ];

  const superadminNavItems = [
    { icon: LayoutDashboard, label: "Overview",      path: "/superadmin" },
    { icon: Users,           label: "Admins",        path: "/superadmin/admins" },
    { icon: CreditCard,      label: "UPI Approvals", path: "/superadmin/upi-approvals", badge: pendingUpiCount },
    { icon: Monitor,         label: "All Machines",  path: "/superadmin/machines" },
    { icon: ClipboardList,   label: "Audit Logs",    path: "/superadmin/audit-logs" },
  ];

  const navItems = isSuperAdmin ? superadminNavItems : adminNavItems;

  const isActive = (path: string) => {
    if (path === "/superadmin") return location.pathname === "/superadmin";
    return location.pathname === path || location.pathname.startsWith(path + "/");
  };

  return (
    <aside className="fixed left-0 top-0 z-40 h-screen w-60 border-r border-sidebar-border bg-sidebar">
      {/* Subtle glow at top */}
      <div
        className="pointer-events-none absolute inset-x-0 top-0 h-32"
        style={{
          background: "radial-gradient(ellipse 100% 60% at 50% 0%, hsl(248 90% 66% / 0.08), transparent)",
        }}
      />

      <div className="relative flex h-full flex-col">
        {/* Logo */}
        <div className="flex h-16 items-center gap-3 border-b border-sidebar-border px-5">
          <img src="/logo.png" alt="MIT Logo" className="h-8 w-8 rounded-lg object-cover" />
          <div className="flex flex-col">
            <span className="text-sm font-semibold leading-none text-sidebar-foreground tracking-tight">
              MIT Admin
            </span>
            <span className="mt-1 text-[10px] font-medium uppercase tracking-widest text-muted-foreground">
              {isSuperAdmin ? "Super Admin" : "Control Panel"}
            </span>
          </div>
        </div>

        {/* Navigation */}
        <nav className="flex-1 space-y-0.5 px-3 py-4">
          <p className="mb-2 px-3 text-[10px] font-semibold uppercase tracking-widest text-muted-foreground/60">
            Navigation
          </p>
          {navItems.map((item) => {
            const active = isActive(item.path);
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`sidebar-item group ${active ? "active" : ""}`}
              >
                <item.icon
                  className={`h-4 w-4 shrink-0 transition-colors ${
                    active ? "text-primary" : "text-muted-foreground group-hover:text-sidebar-foreground"
                  }`}
                />
                <span className="truncate flex-1">{item.label}</span>
                {item.badge != null && item.badge > 0 && (
                  <span className={`ml-auto flex h-5 min-w-5 items-center justify-center rounded-full px-1.5 text-[10px] font-bold text-white ${
                    isSuperAdmin ? "bg-amber-500" : "bg-red-500"
                  }`}>
                    {item.badge > 99 ? "99+" : item.badge}
                  </span>
                )}
                {active && !(item.badge && item.badge > 0) && (
                  <span className="ml-auto h-1.5 w-1.5 rounded-full bg-primary" />
                )}
              </Link>
            );
          })}
        </nav>

        {/* Footer */}
        <div className="border-t border-sidebar-border px-3 py-4">
          {isSuperAdmin && storedUser?.username && (
            <div className="mb-2 flex items-center gap-2 px-3 py-2 rounded-lg bg-secondary/40">
              <div className="flex h-6 w-6 items-center justify-center rounded-full bg-primary/20 text-[10px] font-bold uppercase text-primary shrink-0">
                {storedUser.username[0]}
              </div>
              <span className="text-xs font-medium text-muted-foreground truncate">{storedUser.username}</span>
              <ShieldCheck className="h-3 w-3 text-primary/60 ml-auto shrink-0" />
            </div>
          )}
          <button
            onClick={() => setShowSignOutDialog(true)}
            className="sidebar-item w-full hover:bg-destructive/10 hover:text-destructive group"
          >
            <LogOut className="h-4 w-4 shrink-0 text-muted-foreground transition-colors group-hover:text-destructive" />
            <span>Sign Out</span>
          </button>
        </div>
      </div>

      <AlertDialog open={showSignOutDialog} onOpenChange={setShowSignOutDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Sign out?</AlertDialogTitle>
            <AlertDialogDescription>
              You'll be returned to the login screen.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleLogout}
              className="bg-destructive hover:bg-destructive/90 text-destructive-foreground"
            >
              Sign Out
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </aside>
  );
};

export default Sidebar;
