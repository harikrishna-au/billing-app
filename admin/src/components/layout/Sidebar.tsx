import { Link, useLocation, useNavigate } from "react-router-dom";
import { LayoutDashboard, Monitor, AlertTriangle, LogOut, Zap } from "lucide-react";

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
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/15">
            <Zap className="h-4 w-4 text-primary" />
          </div>
          <div className="flex flex-col">
            <span className="text-sm font-semibold leading-none text-sidebar-foreground tracking-tight">
              Billing Admin
            </span>
            <span className="mt-1 text-[10px] font-medium uppercase tracking-widest text-muted-foreground">
              Control Panel
            </span>
          </div>
        </div>

        {/* Navigation */}
        <nav className="flex-1 space-y-0.5 px-3 py-4">
          <p className="mb-2 px-3 text-[10px] font-semibold uppercase tracking-widest text-muted-foreground/60">
            Navigation
          </p>
          {navItems.map((item) => {
            const isActive = location.pathname === item.path || location.pathname.startsWith(item.path + "/");
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`sidebar-item group ${isActive ? "active" : ""}`}
              >
                <item.icon
                  className={`h-4 w-4 shrink-0 transition-colors ${
                    isActive ? "text-primary" : "text-muted-foreground group-hover:text-sidebar-foreground"
                  }`}
                />
                <span className="truncate">{item.label}</span>
                {isActive && (
                  <span className="ml-auto h-1.5 w-1.5 rounded-full bg-primary" />
                )}
              </Link>
            );
          })}
        </nav>

        {/* Footer */}
        <div className="border-t border-sidebar-border px-3 py-4">
          <button
            onClick={handleLogout}
            className="sidebar-item w-full hover:bg-destructive/10 hover:text-destructive group"
          >
            <LogOut className="h-4 w-4 shrink-0 text-muted-foreground transition-colors group-hover:text-destructive" />
            <span>Sign Out</span>
          </button>
        </div>
      </div>
    </aside>
  );
};

export default Sidebar;
