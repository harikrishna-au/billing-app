import { useParams, useNavigate, Link } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useState, useRef } from "react";
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
import { ArrowLeft, Plus, Edit, Trash2, Loader2, Upload, FileSpreadsheet, CheckCircle2, AlertCircle, X } from "lucide-react";
import { machinesApi, servicesApi } from "@/lib/api";
import { BulkImportResult } from "@/lib/api/services";
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

    // Excel import state
    const fileInputRef = useRef<HTMLInputElement>(null);
    const [isImportDialogOpen, setIsImportDialogOpen] = useState(false);
    const [selectedFile, setSelectedFile] = useState<File | null>(null);
    const [isDragOver, setIsDragOver] = useState(false);
    const [importResult, setImportResult] = useState<BulkImportResult | null>(null);

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

    // Bulk import mutation
    const bulkImportMutation = useMutation({
        mutationFn: (file: File) => servicesApi.bulkImport(id!, file),
        onSuccess: (result) => {
            queryClient.invalidateQueries({ queryKey: ['services', id] });
            setImportResult(result);
            setSelectedFile(null);
            toast({
                title: `✅ Import Complete`,
                description: result.message,
            });
        },
        onError: (error: any) => {
            toast({
                title: "Import Failed",
                description: error?.response?.data?.detail || error.message || "Failed to import services",
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

    const handleFileSelect = (file: File) => {
        const name = file.name.toLowerCase();
        if (!name.endsWith(".xlsx") && !name.endsWith(".xls") && !name.endsWith(".csv")) {
            toast({
                title: "Invalid file type",
                description: "Please upload an Excel (.xlsx, .xls) or CSV (.csv) file",
                variant: "destructive",
            });
            return;
        }
        setSelectedFile(file);
        setImportResult(null);
    };

    const handleDrop = (e: React.DragEvent) => {
        e.preventDefault();
        setIsDragOver(false);
        const file = e.dataTransfer.files[0];
        if (file) handleFileSelect(file);
    };

    const handleImportDialogClose = () => {
        setIsImportDialogOpen(false);
        setSelectedFile(null);
        setImportResult(null);
    };

    const handleConfirmImport = () => {
        if (selectedFile) {
            bulkImportMutation.mutate(selectedFile);
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
                                        <Link to="/clients">Blaze Machines</Link>
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
                            <Button
                                variant="outline"
                                onClick={() => { setIsImportDialogOpen(true); setImportResult(null); setSelectedFile(null); }}
                            >
                                <Upload className="h-4 w-4 mr-2" />
                                Import from Excel
                            </Button>
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
                                <FileSpreadsheet className="h-12 w-12 text-muted-foreground mx-auto mb-4 opacity-40" />
                                <p className="text-muted-foreground mb-2">No services configured for this machine</p>
                                <p className="text-sm text-muted-foreground mb-6">
                                    Add services manually or import from your tariff Excel sheet
                                </p>
                                <div className="flex gap-3 justify-center">
                                    <Button
                                        variant="outline"
                                        onClick={() => setIsImportDialogOpen(true)}
                                    >
                                        <Upload className="h-4 w-4 mr-2" />
                                        Import from Excel
                                    </Button>
                                    <Button onClick={() => setIsAddDialogOpen(true)}>
                                        <Plus className="h-4 w-4 mr-2" />
                                        Add Manually
                                    </Button>
                                </div>
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

                {/* ───────────── Import from Excel Dialog ───────────── */}
                <Dialog open={isImportDialogOpen} onOpenChange={handleImportDialogClose}>
                    <DialogContent className="max-w-lg">
                        <DialogHeader>
                            <DialogTitle className="flex items-center gap-2">
                                <FileSpreadsheet className="h-5 w-5 text-emerald-500" />
                                Import Services from Excel
                            </DialogTitle>
                            <DialogDescription>
                                Upload your tariff sheet (.xlsx or .csv). The file should have columns:
                                <span className="font-medium text-foreground"> "Activity name/details"</span> and
                                <span className="font-medium text-foreground"> "Rate Per Head/Person"</span>.
                            </DialogDescription>
                        </DialogHeader>

                        {/* Success result view */}
                        {importResult ? (
                            <div className="py-4 space-y-4">
                                <div className="flex items-start gap-3 p-4 rounded-lg bg-emerald-500/10 border border-emerald-500/20">
                                    <CheckCircle2 className="h-5 w-5 text-emerald-500 mt-0.5 shrink-0" />
                                    <div>
                                        <p className="font-semibold text-emerald-500">Import Successful</p>
                                        <p className="text-sm text-muted-foreground mt-0.5">{importResult.message}</p>
                                    </div>
                                </div>
                                {importResult.skipped > 0 && (
                                    <div className="space-y-2">
                                        <p className="text-sm font-medium text-muted-foreground flex items-center gap-1">
                                            <AlertCircle className="h-4 w-4 text-amber-500" />
                                            Skipped rows ({importResult.skipped}):
                                        </p>
                                        <div className="rounded-md border divide-y max-h-40 overflow-y-auto text-sm">
                                            {importResult.skipped_details.map((s, i) => (
                                                <div key={i} className="px-3 py-2 flex justify-between text-muted-foreground">
                                                    <span>Row {s.row}</span>
                                                    <span className="text-amber-500">{s.reason}</span>
                                                </div>
                                            ))}
                                        </div>
                                    </div>
                                )}
                            </div>
                        ) : (
                            /* File upload view */
                            <div className="py-4 space-y-4">
                                {/* Drop zone */}
                                <div
                                    className={`relative border-2 border-dashed rounded-xl p-8 text-center transition-all cursor-pointer
                                        ${isDragOver
                                            ? 'border-primary bg-primary/5'
                                            : selectedFile
                                                ? 'border-emerald-500 bg-emerald-500/5'
                                                : 'border-muted-foreground/30 hover:border-primary/50 hover:bg-accent/30'
                                        }`}
                                    onDragOver={(e) => { e.preventDefault(); setIsDragOver(true); }}
                                    onDragLeave={() => setIsDragOver(false)}
                                    onDrop={handleDrop}
                                    onClick={() => fileInputRef.current?.click()}
                                >
                                    <input
                                        ref={fileInputRef}
                                        type="file"
                                        accept=".xlsx,.xls,.csv"
                                        className="hidden"
                                        onChange={(e) => {
                                            const f = e.target.files?.[0];
                                            if (f) handleFileSelect(f);
                                            e.target.value = '';
                                        }}
                                    />

                                    {selectedFile ? (
                                        <div className="space-y-2">
                                            <FileSpreadsheet className="h-10 w-10 text-emerald-500 mx-auto" />
                                            <p className="font-semibold text-foreground">{selectedFile.name}</p>
                                            <p className="text-sm text-muted-foreground">
                                                {(selectedFile.size / 1024).toFixed(1)} KB · Ready to import
                                            </p>
                                            <button
                                                className="text-xs text-muted-foreground underline mt-1 hover:text-foreground"
                                                onClick={(e) => { e.stopPropagation(); setSelectedFile(null); }}
                                            >
                                                Choose a different file
                                            </button>
                                        </div>
                                    ) : (
                                        <div className="space-y-2">
                                            <Upload className="h-10 w-10 text-muted-foreground/50 mx-auto" />
                                            <p className="font-medium text-foreground">
                                                Drop your Excel file here
                                            </p>
                                            <p className="text-sm text-muted-foreground">
                                                or <span className="text-primary underline">browse files</span>
                                            </p>
                                            <p className="text-xs text-muted-foreground/70">
                                                Supports .xlsx, .xls, .csv
                                            </p>
                                        </div>
                                    )}
                                </div>

                                {/* Column hint */}
                                <div className="rounded-lg border bg-muted/30 p-3 text-xs text-muted-foreground space-y-1">
                                    <p className="font-medium text-foreground text-sm mb-2">Expected column headers:</p>
                                    <div className="grid grid-cols-2 gap-2">
                                        <div className="bg-background rounded p-2 border font-mono">
                                            Activity name/details
                                        </div>
                                        <div className="bg-background rounded p-2 border font-mono">
                                            Rate Per Head/Person
                                        </div>
                                    </div>
                                    <p className="text-xs pt-1">Other columns (GST, Sl No, etc.) will be ignored.</p>
                                </div>
                            </div>
                        )}

                        <DialogFooter>
                            <Button variant="outline" onClick={handleImportDialogClose}>
                                {importResult ? "Close" : "Cancel"}
                            </Button>
                            {!importResult && (
                                <Button
                                    onClick={handleConfirmImport}
                                    disabled={!selectedFile || bulkImportMutation.isPending}
                                >
                                    {bulkImportMutation.isPending
                                        ? <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Importing...</>
                                        : <><Upload className="h-4 w-4 mr-2" /> Import Services</>
                                    }
                                </Button>
                            )}
                        </DialogFooter>
                    </DialogContent>
                </Dialog>

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
