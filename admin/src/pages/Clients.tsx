import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import DashboardLayout from "@/components/layout/DashboardLayout";
import StatCard from "@/components/dashboard/StatCard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Plus, Search, MoreHorizontal, Monitor, UserCheck, AlertTriangle, Loader2 } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useToast } from "@/hooks/use-toast";
import { machinesApi } from "@/lib/api";

const Clients = () => {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [searchQuery, setSearchQuery] = useState("");
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [newMachine, setNewMachine] = useState({
    name: "",
    location: "",
    username_prefix: "admin",
    password: ""
  });
  const { toast } = useToast();

  // Fetch all machines
  const { data: machinesData, isLoading } = useQuery({
    queryKey: ['machines'],
    queryFn: () => machinesApi.getAll(),
  });

  const machines = machinesData?.machines || [];

  // Create machine mutation
  const createMutation = useMutation({
    mutationFn: machinesApi.create,
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['machines'] });
      toast({ title: "Machine Added", description: `${newMachine.name} has been added successfully with username ${result.username}.` });
      setIsDialogOpen(false);
      setNewMachine({ name: "", location: "", username_prefix: "admin", password: "" });
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to add machine", variant: "destructive" });
    },
  });

  // Delete machine mutation
  const deleteMutation = useMutation({
    mutationFn: machinesApi.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['machines'] });
      toast({ title: "Machine Deleted", description: "Machine has been removed successfully." });
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to delete machine", variant: "destructive" });
    },
  });

  const filteredMachines = machines.filter(
    (m) =>
      m.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      m.location.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const activeMachines = machines.filter(m => m.status === "online").length;
  const inactiveMachines = machines.filter(m => m.status !== "online").length;
  const totalCollection = machines.reduce((sum, m) => sum + Number(m.online_collection) + Number(m.offline_collection), 0);

  const handleCreateMachine = (e: React.FormEvent) => {
    e.preventDefault();
    createMutation.mutate({
      name: newMachine.name,
      location: newMachine.location,
      username_prefix: newMachine.username_prefix,
      password: newMachine.password,
    });
  };

  const handleDeleteMachine = (id: string) => {
    if (confirm("Are you sure you want to delete this machine?")) {
      deleteMutation.mutate(id);
    }
  };

  return (
    <DashboardLayout>
      <div className="space-y-8">
        <div className="flex items-center justify-between animate-fade-in">
          <div>
            <h1 className="text-3xl font-bold text-foreground">Billing Machines</h1>
            <p className="text-muted-foreground">Manage all your billing machines and their configurations</p>
          </div>

          <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
            <DialogTrigger asChild>
              <Button variant="glow">
                <Plus className="h-4 w-4 mr-2" />
                Add Machine
              </Button>
            </DialogTrigger>
            <DialogContent className="bg-card border-border">
              <DialogHeader>
                <DialogTitle>Add New Machine</DialogTitle>
                <DialogDescription>Create a new billing machine entry</DialogDescription>
              </DialogHeader>
              <form onSubmit={handleCreateMachine} className="space-y-4">
                <div>
                  <Label htmlFor="name">Machine Name</Label>
                  <Input
                    id="name"
                    value={newMachine.name}
                    onChange={(e) => setNewMachine({ ...newMachine, name: e.target.value })}
                    placeholder="e.g. Main Entrance POS"
                    className="bg-secondary/50"
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="location">Location</Label>
                  <Input
                    id="location"
                    value={newMachine.location}
                    onChange={(e) => setNewMachine({ ...newMachine, location: e.target.value })}
                    placeholder="e.g. Lobby A"
                    className="bg-secondary/50"
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="username_prefix">Username Prefix</Label>
                  <Input
                    id="username_prefix"
                    value={newMachine.username_prefix}
                    onChange={(e) => setNewMachine({ ...newMachine, username_prefix: e.target.value })}
                    placeholder="admin"
                    className="bg-secondary/50"
                    required
                  />
                  <p className="text-xs text-muted-foreground mt-1">
                    Username will be auto-generated as: {newMachine.username_prefix}XXX
                  </p>
                </div>
                <div>
                  <Label htmlFor="password">Password</Label>
                  <Input
                    id="password"
                    type="password"
                    value={newMachine.password}
                    onChange={(e) => setNewMachine({ ...newMachine, password: e.target.value })}
                    placeholder="Enter machine password"
                    className="bg-secondary/50"
                    required
                    minLength={4}
                  />
                </div>
                <div className="flex justify-end gap-3">
                  <Button type="button" variant="outline" onClick={() => setIsDialogOpen(false)}>
                    Cancel
                  </Button>
                  <Button type="submit" variant="glow" disabled={createMutation.isPending}>
                    {createMutation.isPending ? "Adding..." : "Add Machine"}
                  </Button>
                </div>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <div className="grid gap-6 md:grid-cols-3 animate-slide-up">
          <StatCard
            title="Total Machines"
            value={machines.length.toString()}
            icon={Monitor}
          />
          <StatCard
            title="Active Machines"
            value={activeMachines.toString()}
            icon={UserCheck}
          />
          <StatCard
            title="Total Collection"
            value={`₹${totalCollection.toLocaleString()}`}
            icon={AlertTriangle}
          />
        </div>

        <div className="stat-card animate-slide-up" style={{ animationDelay: "0.1s" }}>
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-semibold text-foreground">All Machines</h2>
            <div className="relative w-64">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search machines..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10 bg-secondary/50"
              />
            </div>
          </div>

          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          ) : filteredMachines.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground">
              {searchQuery ? "No machines found matching your search" : "No machines yet. Add your first machine to get started."}
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border/50">
                    <th className="text-left py-3 px-4 text-sm font-medium text-muted-foreground">Machine</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-muted-foreground">Location</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-muted-foreground">Username</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-muted-foreground">Status</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-muted-foreground">Online</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-muted-foreground">Offline</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-muted-foreground">Last Sync</th>
                    <th className="text-right py-3 px-4 text-sm font-medium text-muted-foreground">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredMachines.map((machine) => (
                    <tr
                      key={machine.id}
                      className="border-b border-border/30 hover:bg-accent/50 transition-colors cursor-pointer"
                      onClick={() => navigate(`/clients/${machine.id}`)}
                    >
                      <td className="py-3 px-4 font-medium text-foreground">{machine.name}</td>
                      <td className="py-3 px-4 text-muted-foreground">{machine.location}</td>
                      <td className="py-3 px-4 text-muted-foreground font-mono text-sm">{machine.username}</td>
                      <td className="py-3 px-4">
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${machine.status === 'online'
                          ? 'bg-emerald-500/10 text-emerald-500'
                          : machine.status === 'offline'
                            ? 'bg-red-500/10 text-red-500'
                            : 'bg-amber-500/10 text-amber-500'
                          }`}>
                          {machine.status.toUpperCase()}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-foreground">₹{Number(machine.online_collection).toLocaleString()}</td>
                      <td className="py-3 px-4 text-foreground">₹{Number(machine.offline_collection).toLocaleString()}</td>
                      <td className="py-3 px-4 text-muted-foreground text-sm">
                        {new Date(machine.last_sync).toLocaleString()}
                      </td>
                      <td className="py-3 px-4 text-right">
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild onClick={(e) => e.stopPropagation()}>
                            <Button variant="ghost" size="icon" className="h-8 w-8">
                              <MoreHorizontal className="h-4 w-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuItem onClick={(e) => {
                              e.stopPropagation();
                              navigate(`/clients/${machine.id}`);
                            }}>
                              View Details
                            </DropdownMenuItem>
                            <DropdownMenuItem onClick={(e) => {
                              e.stopPropagation();
                              navigate(`/clients/${machine.id}/catalog`);
                            }}>
                              Manage Catalog
                            </DropdownMenuItem>
                            <DropdownMenuItem onClick={(e) => {
                              e.stopPropagation();
                              navigate(`/clients/${machine.id}/payments`);
                            }}>
                              View Payments
                            </DropdownMenuItem>
                            <DropdownMenuItem
                              className="text-destructive"
                              onClick={(e) => {
                                e.stopPropagation();
                                handleDeleteMachine(machine.id);
                              }}
                            >
                              Delete Machine
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </DashboardLayout>
  );
};

export default Clients;
