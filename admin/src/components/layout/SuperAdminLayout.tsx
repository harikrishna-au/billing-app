import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "./DashboardLayout";

interface SuperAdminLayoutProps {
  children: React.ReactNode;
}

const SuperAdminLayout = ({ children }: SuperAdminLayoutProps) => {
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem("access_token");
    if (!token) { navigate("/login"); return; }
    try {
      const user = JSON.parse(localStorage.getItem("user") || "{}");
      if (user?.role !== "superadmin") navigate("/dashboard");
    } catch {
      navigate("/login");
    }
  }, [navigate]);

  return <DashboardLayout>{children}</DashboardLayout>;
};

export default SuperAdminLayout;
