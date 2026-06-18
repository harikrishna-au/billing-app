import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import Index from "./pages/Index";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import Clients from "./pages/Clients";
import ClientDashboard from "./pages/ClientDashboard";
import MachineCatalog from "./pages/MachineCatalog";
import MachinePayments from "./pages/MachinePayments";
import MachineLogs from "./pages/MachineLogs";
import Alerts from "./pages/Alerts";
import BillSettings from "./pages/BillSettings";
import NotFound from "./pages/NotFound";
import Signup from "./pages/Signup";
import { ProtectedRoute } from "./components/ProtectedRoute";
import Overview from "./pages/superadmin/Overview";
import AdminsPage from "./pages/superadmin/AdminsPage";
import UpiApprovalsPage from "./pages/superadmin/UpiApprovalsPage";
import MachinesPage from "./pages/superadmin/MachinesPage";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Index />} />
          <Route path="/login" element={<Login />} />
          <Route path="/portal/:token" element={<Signup />} />
          <Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
          <Route path="/alerts" element={<ProtectedRoute><Alerts /></ProtectedRoute>} />
          <Route path="/clients" element={<ProtectedRoute><Clients /></ProtectedRoute>} />
          <Route path="/clients/:id" element={<ProtectedRoute><ClientDashboard /></ProtectedRoute>} />
          <Route path="/clients/:id/catalog" element={<ProtectedRoute><MachineCatalog /></ProtectedRoute>} />
          <Route path="/clients/:id/payments" element={<ProtectedRoute><MachinePayments /></ProtectedRoute>} />
          <Route path="/clients/:id/logs" element={<ProtectedRoute><MachineLogs /></ProtectedRoute>} />
          <Route path="/clients/:id/catalog-logs" element={<ProtectedRoute><MachineLogs /></ProtectedRoute>} />
          <Route path="/clients/:id/bill-settings" element={<ProtectedRoute><BillSettings /></ProtectedRoute>} />
          {/* Superadmin portal — completely separate from admin panel */}
          <Route path="/superadmin" element={<ProtectedRoute superadminOnly><Overview /></ProtectedRoute>} />
          <Route path="/superadmin/admins" element={<ProtectedRoute superadminOnly><AdminsPage /></ProtectedRoute>} />
          <Route path="/superadmin/upi-approvals" element={<ProtectedRoute superadminOnly><UpiApprovalsPage /></ProtectedRoute>} />
          <Route path="/superadmin/machines" element={<ProtectedRoute superadminOnly><MachinesPage /></ProtectedRoute>} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
