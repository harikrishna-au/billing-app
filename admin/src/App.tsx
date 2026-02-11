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
import NotFound from "./pages/NotFound";

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
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/alerts" element={<Alerts />} />
          <Route path="/clients" element={<Clients />} />
          <Route path="/clients/:id" element={<ClientDashboard />} />
          <Route path="/clients/:id/catalog" element={<MachineCatalog />} />
          <Route path="/clients/:id/payments" element={<MachinePayments />} />
          <Route path="/clients/:id/logs" element={<MachineLogs />} />
          <Route path="/clients/:id/catalog-logs" element={<MachineLogs />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
