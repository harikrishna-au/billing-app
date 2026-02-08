import { Link, useLocation, useNavigate } from "react-router-dom";
import { LayoutDashboard, Users, LogOut, Ticket, Monitor, AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";

const Sidebar = () => {
  const location = useLocation();
  const navigate = useNavigate();

  const handleLogout = () => {
    localStorage.removeItem("adminSession");
    navigate("/");
  };

  const navItems = [
    { icon: LayoutDashboard, label: "Dashboard", path: "/dashboard" },
    { icon: Monitor, label: "Billing Machines", path: "/clients" },
    { icon: AlertTriangle, label: "System Alerts", path: "/alerts" },
  ];

  return (
    <aside className="fixed left-0 top-0 z-40 h-screen w-64 border-r border-sidebar-border bg-sidebar">
      <div className="flex h-full flex-col">
        {/* Logo */}
        <div className="flex h-16 items-center gap-3 border-b border-sidebar-border px-6">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10">
            <Ticket className="h-5 w-5 text-primary" />
          </div>
          <span className="text-lg font-semibold text-sidebar-foreground">
            Billing Admin
          </span>
        </div>

        {/* Navigation */}
        <nav className="flex-1 space-y-1 p-4">
          {navItems.map((item) => {
            const isActive = location.pathname === item.path;
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`sidebar-item ${isActive ? "active" : ""}`}
              >
                <item.icon className="h-5 w-5" />
                {item.label}
              </Link>
            );
          })}
        </nav>

        {/* Logout */}
        <div className="border-t border-sidebar-border p-4">
          <Button
            variant="ghost"
            className="w-full justify-start gap-3 text-muted-foreground hover:text-foreground"
            onClick={handleLogout}
          >
            <LogOut className="h-5 w-5" />
            Sign Out
          </Button>
        </div>
      </div>
    </aside>
  );
};

export default Sidebar;
