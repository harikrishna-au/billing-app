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
import { Separator } from "@/components/ui/separator";
import { Plus, Search, MoreHorizontal, Monitor, UserCheck, AlertTriangle, Loader2, Pencil, Trash2, MapPin } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useToast } from "@/hooks/use-toast";
import { machinesApi, locationsApi, type Machine as MachineType, type LocationType } from "@/lib/api";

const Clients = () => {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [searchQuery, setSearchQuery] = useState("");
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [newMachine, setNewMachine] = useState({
    name: "",
    location: "",
    location_id: "",
    username_prefix: "admin",
    password: ""
  });
  const [editingMachine, setEditingMachine] = useState<MachineType | null>(null);
  const [editForm, setEditForm] = useState({ name: "", location: "", location_id: "", password: "" });

  // Location management state
  const [isAddLocationOpen, setIsAddLocationOpen] = useState(false);
  const [editingLocation, setEditingLocation] = useState<LocationType | null>(null);
  const [locationForm, setLocationForm] = useState({ name: "", upi_id: "" });

  const { toast } = useToast();

  // Fetch all machines — poll every 30 s so status changes appear automatically
  const { data: machinesData, isLoading } = useQuery({
    queryKey: ['machines'],
    queryFn: () => machinesApi.getAll(),
    refetchInterval: 30_000,
  });

  // Fetch locations
  const { data: locations = [] } = useQuery({
    queryKey: ['locations'],
    queryFn: () => locationsApi.getAll(),
  });

  const machines = machinesData?.machines || [];

  // Create machine mutation
  const createMutation = useMutation({
    mutationFn: machinesApi.create,
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['machines'] });
      toast({ title: "Machine Added", description: `${newMachine.name} has been added successfully with username ${result.username}.` });
      setIsDialogOpen(false);
      setNewMachine({ name: "", location: "", location_id: "", username_prefix: "admin", password: "" });
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

  // Update machine mutation
  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: Parameters<typeof machinesApi.update>[1] }) =>
      machinesApi.update(id, data),
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['machines'] });
      toast({ title: "Machine Updated", description: `${result.name} has been updated successfully.` });
      setEditingMachine(null);
    },
    onError: (error: any) => {
      const detail = error?.response?.data?.detail || error?.message || "Failed to update machine";
      toast({ title: "Error", description: detail, variant: "destructive" });
    },
  });

  // Location mutations
  const createLocationMutation = useMutation({
    mutationFn: locationsApi.create,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['locations'] });
      toast({ title: "Location Added", description: `${locationForm.name} has been added.` });
      setIsAddLocationOpen(false);
      setLocationForm({ name: "", upi_id: "" });
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to add location", variant: "destructive" });
    },
  });

  const updateLocationMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: { name?: string; upi_id?: string } }) =>
      locationsApi.update(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['locations'] });
      toast({ title: "Location Updated" });
      setEditingLocation(null);
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to update location", variant: "destructive" });
    },
  });

  const deleteLocationMutation = useMutation({
    mutationFn: locationsApi.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['locations'] });
      toast({ title: "Location Deleted" });
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to delete location", variant: "destructive" });
    },
  });

  const filteredMachines = machines.filter(
    (m) =>
      m.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      m.location.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const activeMachines = machines.filter(m => m.status === "online").length;
  const totalCollection = machines.reduce((sum, m) => sum + Number(m.online_collection) + Number(m.offline_collection), 0);

  const handleCreateMachine = (e: React.FormEvent) => {
    e.preventDefault();
    createMutation.mutate({
      name: newMachine.name,
      location: newMachine.location,
      username_prefix: newMachine.username_prefix,
      password: newMachine.password,
      location_id: newMachine.location_id || undefined,
    });
  };

  const handleDeleteMachine = (id: string) => {
    if (confirm("Are you sure you want to delete this machine?")) {
      deleteMutation.mutate(id);
    }
  };

  const handleOpenEdit = (machine: MachineType, e: React.MouseEvent) => {
    e.stopPropagation();
    setEditForm({
      name: machine.name,
      location: machine.location,
      location_id: (machine as any).location_id ?? "",
      password: "",
    });
    setEditingMachine(machine);
  };

  const handleUpdateMachine = (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingMachine) return;
    const data: Parameters<typeof machinesApi.update>[1] = {
      name: editForm.name || undefined,
      location: editForm.location || undefined,
      location_id: editForm.location_id || undefined,
    };
    if (editForm.password) data.password = editForm.password;
    updateMutation.mutate({ id: editingMachine.id, data });
  };

  const handleLocationSelect = (locationId: string, setter: (v: any) => void, current: any) => {
    const loc = locations.find(l => l.id === locationId);
    setter({ ...current, location_id: locationId, location: loc?.name ?? current.location });
  };

  const handleOpenEditLocation = (loc: LocationType) => {
    setLocationForm({ name: loc.name, upi_id: loc.upi_id ?? "" });
    setEditingLocation(loc);
  };

  const handleSaveLocation = (e: React.FormEvent) => {
    e.preventDefault();
    if (editingLocation) {
      updateLocationMutation.mutate({ id: editingLocation.id, data: { name: locationForm.name, upi_id: locationForm.upi_id } });
    } else {
      createLocationMutation.mutate({ name: locationForm.name, upi_id: locationForm.upi_id || undefined });
    }
  };

  return (
    <DashboardLayout>
      <div className="space-y-8">
        <div className="flex items-center justify-between animate-fade-in">
          <div>
            <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-1">Management</p>
            <h1 className="text-2xl font-semibold text-foreground">Hadoom Machines</h1>
            <p className="text-sm text-muted-foreground">Manage all your Hadoom machines and their configurations</p>
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
                <DialogDescription>Create a new Hadoom machine entry</DialogDescription>
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
                  <Label htmlFor="location_id">Location</Label>
                  {locations.length > 0 ? (
                    <select
                      id="location_id"
                      value={newMachine.location_id}
                      onChange={(e) => handleLocationSelect(e.target.value, setNewMachine, newMachine)}
                      className="w-full rounded-md border border-input bg-secondary/50 px-3 py-2 text-sm"
                    >
                      <option value="">— Select a location —</option>
                      {locations.map(loc => (
                        <option key={loc.id} value={loc.id}>{loc.name}</option>
                      ))}
                    </select>
                  ) : (
                    <Input
                      id="location"
                      value={newMachine.location}
                      onChange={(e) => setNewMachine({ ...newMachine, location: e.target.value })}
                      placeholder="e.g. Lobby A"
                      className="bg-secondary/50"
                      required
                    />
                  )}
                  {locations.length > 0 && !newMachine.location_id && (
                    <Input
                      value={newMachine.location}
                      onChange={(e) => setNewMachine({ ...newMachine, location: e.target.value })}
                      placeholder="Or type a custom location name"
                      className="bg-secondary/50 mt-2"
                    />
                  )}
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

        {/* Edit Machine Dialog */}
        <Dialog open={!!editingMachine} onOpenChange={(open) => !open && setEditingMachine(null)}>
          <DialogContent className="bg-card border-border">
            <DialogHeader>
              <DialogTitle>Edit Machine</DialogTitle>
              <DialogDescription>Update machine details for {editingMachine?.name}</DialogDescription>
            </DialogHeader>
            <form onSubmit={handleUpdateMachine} className="space-y-4">
              <div>
                <Label htmlFor="edit-name">Machine Name</Label>
                <Input
                  id="edit-name"
                  value={editForm.name}
                  onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                  placeholder="e.g. Main Entrance POS"
                  className="bg-secondary/50"
                  required
                />
              </div>
              <div>
                <Label htmlFor="edit-location-id">Location</Label>
                {locations.length > 0 ? (
                  <select
                    id="edit-location-id"
                    value={editForm.location_id}
                    onChange={(e) => handleLocationSelect(e.target.value, setEditForm, editForm)}
                    className="w-full rounded-md border border-input bg-secondary/50 px-3 py-2 text-sm"
                  >
                    <option value="">— Select a location —</option>
                    {locations.map(loc => (
                      <option key={loc.id} value={loc.id}>{loc.name}</option>
                    ))}
                  </select>
                ) : (
                  <Input
                    id="edit-location"
                    value={editForm.location}
                    onChange={(e) => setEditForm({ ...editForm, location: e.target.value })}
                    placeholder="e.g. Lobby A"
                    className="bg-secondary/50"
                    required
                  />
                )}
                {locations.length > 0 && !editForm.location_id && (
                  <Input
                    value={editForm.location}
                    onChange={(e) => setEditForm({ ...editForm, location: e.target.value })}
                    placeholder="Or type a custom location name"
                    className="bg-secondary/50 mt-2"
                  />
                )}
              </div>
              <Separator />
              <div>
                <Label htmlFor="edit-password">New Password</Label>
                <Input
                  id="edit-password"
                  type="password"
                  value={editForm.password}
                  onChange={(e) => setEditForm({ ...editForm, password: e.target.value })}
                  placeholder="Leave blank to keep current password"
                  className="bg-secondary/50"
                  minLength={4}
                />
              </div>
              <div className="flex justify-end gap-3">
                <Button type="button" variant="outline" onClick={() => setEditingMachine(null)}>
                  Cancel
                </Button>
                <Button type="submit" variant="glow" disabled={updateMutation.isPending}>
                  {updateMutation.isPending ? "Saving..." : "Save Changes"}
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>

        {/* Add/Edit Location Dialog */}
        <Dialog
          open={isAddLocationOpen || !!editingLocation}
          onOpenChange={(open) => { if (!open) { setIsAddLocationOpen(false); setEditingLocation(null); setLocationForm({ name: "", upi_id: "" }); } }}
        >
          <DialogContent className="bg-card border-border">
            <DialogHeader>
              <DialogTitle>{editingLocation ? "Edit Location" : "Add Location"}</DialogTitle>
              <DialogDescription>
                {editingLocation ? `Update details for ${editingLocation.name}` : "Create a new location with a UPI ID"}
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleSaveLocation} className="space-y-4">
              <div>
                <Label htmlFor="loc-name">Location Name</Label>
                <Input
                  id="loc-name"
                  value={locationForm.name}
                  onChange={(e) => setLocationForm({ ...locationForm, name: e.target.value })}
                  placeholder="e.g. Gate A"
                  className="bg-secondary/50"
                  required
                />
              </div>
              <div>
                <Label htmlFor="loc-upi">UPI ID</Label>
                <Input
                  id="loc-upi"
                  value={locationForm.upi_id}
                  onChange={(e) => setLocationForm({ ...locationForm, upi_id: e.target.value })}
                  placeholder="merchant@upi"
                  className="bg-secondary/50"
                />
                <p className="text-xs text-muted-foreground mt-1">All machines at this location will use this UPI ID</p>
              </div>
              <div className="flex justify-end gap-3">
                <Button type="button" variant="outline" onClick={() => { setIsAddLocationOpen(false); setEditingLocation(null); }}>
                  Cancel
                </Button>
                <Button type="submit" variant="glow" disabled={createLocationMutation.isPending || updateLocationMutation.isPending}>
                  {editingLocation ? "Save Changes" : "Add Location"}
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>

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

        {/* Locations Section */}
        <div className="stat-card animate-slide-up" style={{ animationDelay: "0.05s" }}>
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <MapPin className="h-5 w-5 text-muted-foreground" />
              <h2 className="text-xl font-semibold text-foreground">Locations</h2>
            </div>
            <Button variant="outline" size="sm" onClick={() => { setLocationForm({ name: "", upi_id: "" }); setIsAddLocationOpen(true); }}>
              <Plus className="h-4 w-4 mr-1" />
              Add Location
            </Button>
          </div>

          {locations.length === 0 ? (
            <p className="text-sm text-muted-foreground py-4 text-center">No locations yet. Add a location to manage UPI IDs centrally.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border">
                    <th className="text-left py-2 px-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Name</th>
                    <th className="text-left py-2 px-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground">UPI ID</th>
                    <th className="text-right py-2 px-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {locations.map((loc) => (
                    <tr key={loc.id} className="border-b border-border/30">
                      <td className="py-2 px-3 text-sm font-medium text-foreground">{loc.name}</td>
                      <td className="py-2 px-3 text-sm text-muted-foreground font-mono">{loc.upi_id || <span className="text-muted-foreground/50 italic">not set</span>}</td>
                      <td className="py-2 px-3 text-right">
                        <div className="flex justify-end gap-1">
                          <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => handleOpenEditLocation(loc)}>
                            <Pencil className="h-3.5 w-3.5" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-7 w-7 text-destructive hover:text-destructive"
                            onClick={() => {
                              if (confirm(`Delete location "${loc.name}"?`)) deleteLocationMutation.mutate(loc.id);
                            }}
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
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
                  <tr className="border-b border-border">
                    <th className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Machine</th>
                    <th className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Location</th>
                    <th className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Username</th>
                    <th className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Status</th>
                    <th className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Online</th>
                    <th className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Offline</th>
                    <th className="text-left py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Last Sync</th>
                    <th className="text-right py-3 px-4 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredMachines.map((machine) => (
                    <tr
                      key={machine.id}
                      className="border-b border-border/30 hover:bg-accent/50 transition-colors cursor-pointer"
                      onClick={() => navigate(`/clients/${machine.id}`)}
                    >
                      <td className="py-3 px-4 font-medium text-foreground text-sm">{machine.name}</td>
                      <td className="py-3 px-4 text-muted-foreground text-sm">{machine.location}</td>
                      <td className="py-3 px-4 text-muted-foreground font-mono text-xs">{machine.username}</td>
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
                      <td className="py-3 px-4 text-foreground font-mono text-sm">₹{Number(machine.online_collection).toLocaleString()}</td>
                      <td className="py-3 px-4 text-foreground font-mono text-sm">₹{Number(machine.offline_collection).toLocaleString()}</td>
                      <td className="py-3 px-4 text-muted-foreground text-xs font-mono">
                        {machine.last_sync ? new Date(machine.last_sync).toLocaleString() : '—'}
                      </td>
                      <td className="py-3 px-4 text-right">
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild onClick={(e) => e.stopPropagation()}>
                            <Button variant="ghost" size="icon" className="h-8 w-8">
                              <MoreHorizontal className="h-4 w-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuItem onClick={(e) => handleOpenEdit(machine, e)}>
                              <Pencil className="h-4 w-4 mr-2" />
                              Edit Machine
                            </DropdownMenuItem>
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
