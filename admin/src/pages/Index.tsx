import { useEffect } from "react";
import { useNavigate } from "react-router-dom";

const Index = () => {
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem("access_token");
    if (!token) {
      navigate("/login");
      return;
    }
    try {
      const user = JSON.parse(localStorage.getItem("user") || "{}");
      if (user?.role === "superadmin") {
        navigate("/superadmin");
      } else {
        navigate("/dashboard");
      }
    } catch {
      navigate("/dashboard");
    }
  }, [navigate]);

  return null;
};

export default Index;
