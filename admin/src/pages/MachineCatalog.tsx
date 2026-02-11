import { useParams, useNavigate, Link } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog";
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "@/components/ui/select";
import { ArrowLeft, Plus, Edit, Trash2, Loader2 } from "lucide-react";
import { machinesApi, servicesApi } from "@/lib/api";
import {
    Breadcrumb,
    BreadcrumbItem,
    BreadcrumbLink,
    BreadcrumbList,
    BreadcrumbPage,
    BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";
import { useToast } from "@/hooks/use-toast";

interface ServiceFormData {
    name: string;
    price: string;
    status: "active" | "inactive";
}

const MachineCatalog = () => {
    const { id } = useParams();
    const navigate = useNavigate();
    const { toast } = useToast();
    const queryClient = useQueryClient();

    const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
    const [isEditDialogOpen, setIsEditDialogOpen] = useState(false);
    const [editingService, setEditingService] = useState<any>(null);
    const [formData, setFormData] = useState<ServiceFormData>({
        name: "",
        price: "",
        status: "active",
    });

    // Fetch machine data
    const { data: machine, isLoading: machineLoading } = useQuery({
        queryKey: ['machine', id],
        queryFn: () => machinesApi.getById(id!),
        enabled: !!id,
    });

    // Fetch services
    const { data: services = [], isLoading: servicesLoading } = useQuery({
        queryKey: ['services', id],
        queryFn: () => servicesApi.getByMachine(id!),
        enabled: !!id,
    });

    // Create service mutation
    const createMutation = useMutation({
        mutationFn: (data: any) => servicesApi.create({ machine_id: id!, ...data }),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['services', id] });
            setIsAddDialogOpen(false);
            setFormData({ name: "", price: "", status: "active" });
            toast({
                title: "Success",
                description: "Service created successfully",
            });
        },
        onError: (error: any) => {
            toast({
                title: "Error",
                description: error.message || "Failed to create service",
                variant: "destructive",
            });
        },
    });

    // Update service mutation
    const updateMutation = useMutation({
        mutationFn: ({ serviceId, data }: { serviceId: string; data: any }) =>
            servicesApi.update(serviceId, data),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['services', id] });
            setIsEditDialogOpen(false);
            setEditingService(null);
            toast({
                title: "Success",
                description: "Service updated successfully",
            });
        },
        onError: (error: any) => {
            toast({
                title: "Error",
                description: error.message || "Failed to update service",
                variant: "destructive",
            });
        },
    });

    // Delete service mutation
    const deleteMutation = useMutation({
        mutationFn: (serviceId: string) => servicesApi.delete(serviceId),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['services', id] });
            toast({
                title: "Success",
                description: "Service deleted successfully",
            });
        },
        onError: (error: any) => {
            toast({
                title: "Error",
                description: error.message || "Failed to delete service",
                variant: "destructive",
            });
        },
    });

    const handleCreate = () => {
        createMutation.mutate({
            name: formData.name,
            price: parseFloat(formData.price),
            status: formData.status,
        });
    };

    const handleEdit = (service: any) => {
        setEditingService(service);
        setFormData({
            name: service.name,
            price: service.price.toString(),
            status: service.status,
        });
        setIsEditDialogOpen(true);
    };

    const handleUpdate = () => {
        if (editingService) {
            updateMutation.mutate({
                serviceId: editingService.id,
                data: {
                    name: formData.name,
                    price: parseFloat(formData.price),
                    status: formData.status,
                },
            });
        }
    };

    const handleDelete = (serviceId: string) => {
        if (confirm("Are you sure you want to delete this service?")) {
            deleteMutation.mutate(serviceId);
        }
    };

    if (machineLoading || servicesLoading) {
        return (
            <DashboardLayout>
                <div className="flex items-center justify-center h-96">
                    <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
                </div>
            </DashboardLayout>
        );
    }

    if (!machine) {
        return (
            <DashboardLayout>
                <div className="flex flex-col items-center justify-center py-20">
                    <p className="text-lg text-muted-foreground mb-4">Machine not found</p>
                    <Button variant="outline" onClick={() => navigate("/clients")}>
                        <ArrowLeft className="h-4 w-4 mr-2" />
                        Back to Machines
                    </Button>
                </div>
            </DashboardLayout>
        );
    }

    return (
        <DashboardLayout>
            <div className="space-y-6">
                {/* Header */}
                <div>
                    <div className="mb-4 -ml-1">
                        <Breadcrumb>
                            <BreadcrumbList>
                                <BreadcrumbItem>
                                    <BreadcrumbLink asChild>
                                        <Link to="/dashboard">Home</Link>
                                    </BreadcrumbLink>
                                </BreadcrumbItem>
                                <BreadcrumbSeparator />
                                <BreadcrumbItem>
                                    <BreadcrumbLink asChild>
                                        <Link to="/clients">Billing Machines</Link>
                                    </BreadcrumbLink>
                                </BreadcrumbItem>
                                <BreadcrumbSeparator />
                                <BreadcrumbItem>
                                    <BreadcrumbLink asChild>
                                        <Link to={`/clients/${id}`}>{machine.name}</Link>
                                    </BreadcrumbLink>
                                </BreadcrumbItem>
                                <BreadcrumbSeparator />
                                <BreadcrumbItem>
                                    <BreadcrumbPage>Service Catalog</BreadcrumbPage>
                                </BreadcrumbItem>
                            </BreadcrumbList>
                        </Breadcrumb>
                    </div>

                    <div className="flex items-center justify-between">
                        <div>
                            <h1 className="text-3xl font-bold text-foreground">Service Catalog</h1>
                            <p className="text-muted-foreground">{machine.name} - {machine.location}</p>
                        </div>
                        <div className="flex gap-2">
                            <Button onClick={() => setIsAddDialogOpen(true)}>
                                <Plus className="h-4 w-4 mr-2" />
                                Add Service
                            </Button>
                            <Button variant="outline" onClick={() => navigate(`/clients/${id}`)}>
                                <ArrowLeft className="h-4 w-4 mr-2" />
                                Back
                            </Button>
                        </div>
                    </div>
                </div>

                {/* Services List */}
                <div className="stat-card">
                    <div className="space-y-4">
                        {services.length === 0 ? (
                            <div className="text-center py-12">
                                <p className="text-muted-foreground mb-4">No services configured for this machine</p>
                                <Button onClick={() => setIsAddDialogOpen(true)}>
                                    <Plus className="h-4 w-4 mr-2" />
                                    Add Your First Service
                                </Button>
                            </div>
                        ) : (
                            <div className="grid gap-4">
                                {services.map((service) => (
                                    <div
                                        key={service.id}
                                        className="flex items-center justify-between p-4 rounded-lg border bg-card hover:bg-accent/50 transition-colors"
                                    >
                                        <div className="flex-1">
                                            <h3 className="font-semibold text-foreground">{service.name}</h3>
                                            <p className="text-sm text-muted-foreground">
                                                Price: ₹{service.price} | Created: {new Date(service.created_at).toLocaleDateString()}
                                            </p>
                                        </div>
                                        <div className="flex items-center gap-3">
                                            <span
                                                className={`px-3 py-1 rounded-full text-sm font-medium ${service.status === 'active'
                                                    ? 'bg-emerald-500/10 text-emerald-500'
                                                    : 'bg-muted text-muted-foreground'
                                                    }`}
                                            >
                                                {service.status}
                                            </span>
                                            <Button
                                                variant="ghost"
                                                size="sm"
                                                onClick={() => handleEdit(service)}
                                            >
                                                <Edit className="h-4 w-4" />
                                            </Button>
                                            <Button
                                                variant="ghost"
                                                size="sm"
                                                onClick={() => handleDelete(service.id)}
                                            >
                                                <Trash2 className="h-4 w-4 text-destructive" />
                                            </Button>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                </div>

                {/* Add Service Dialog */}
                <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
                    <DialogContent>
                        <DialogHeader>
                            <DialogTitle>Add New Service</DialogTitle>
                            <DialogDescription>
                                Create a new service for {machine.name}
                            </DialogDescription>
                        </DialogHeader>
                        <div className="space-y-4 py-4">
                            <div className="space-y-2">
                                <Label htmlFor="name">Service Name</Label>
                                <Input
                                    id="name"
                                    value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                    placeholder="e.g., Haircut, Massage, Consultation"
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="price">Price (₹)</Label>
                                <Input
                                    id="price"
                                    type="number"
                                    step="0.01"
                                    value={formData.price}
                                    onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                                    placeholder="0.00"
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="status">Status</Label>
                                <Select
                                    value={formData.status}
                                    onValueChange={(value: "active" | "inactive") =>
                                        setFormData({ ...formData, status: value })
                                    }
                                >
                                    <SelectTrigger>
                                        <SelectValue />
                                    </SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="active">Active</SelectItem>
                                        <SelectItem value="inactive">Inactive</SelectItem>
                                    </SelectContent>
                                </Select>
                            </div>
                        </div>
                        <DialogFooter>
                            <Button variant="outline" onClick={() => setIsAddDialogOpen(false)}>
                                Cancel
                            </Button>
                            <Button onClick={handleCreate} disabled={createMutation.isPending}>
                                {createMutation.isPending && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
                                Create Service
                            </Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>

                {/* Edit Service Dialog */}
                <Dialog open={isEditDialogOpen} onOpenChange={setIsEditDialogOpen}>
                    <DialogContent>
                        <DialogHeader>
                            <DialogTitle>Edit Service</DialogTitle>
                            <DialogDescription>
                                Update service details
                            </DialogDescription>
                        </DialogHeader>
                        <div className="space-y-4 py-4">
                            <div className="space-y-2">
                                <Label htmlFor="edit-name">Service Name</Label>
                                <Input
                                    id="edit-name"
                                    value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="edit-price">Price (₹)</Label>
                                <Input
                                    id="edit-price"
                                    type="number"
                                    step="0.01"
                                    value={formData.price}
                                    onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="edit-status">Status</Label>
                                <Select
                                    value={formData.status}
                                    onValueChange={(value: "active" | "inactive") =>
                                        setFormData({ ...formData, status: value })
                                    }
                                >
                                    <SelectTrigger>
                                        <SelectValue />
                                    </SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="active">Active</SelectItem>
                                        <SelectItem value="inactive">Inactive</SelectItem>
                                    </SelectContent>
                                </Select>
                            </div>
                        </div>
                        <DialogFooter>
                            <Button variant="outline" onClick={() => setIsEditDialogOpen(false)}>
                                Cancel
                            </Button>
                            <Button onClick={handleUpdate} disabled={updateMutation.isPending}>
                                {updateMutation.isPending && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
                                Update Service
                            </Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </div>
        </DashboardLayout>
    );
};

export default MachineCatalog;
