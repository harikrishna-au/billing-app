// Database Enums
export type MachineStatus = 'online' | 'offline' | 'maintenance';
export type ServiceStatus = 'active' | 'inactive';
export type LogType = 'login' | 'client' | 'config' | 'manager' | 'system';
export type HistoryType = 'update' | 'create' | 'delete' | 'status';
export type PaymentMethod = 'UPI' | 'Card' | 'Cash';
export type PaymentStatus = 'success' | 'pending' | 'failed';

// Database Tables
export interface Machine {
    id: string;
    name: string;
    location: string;
    status: MachineStatus;
    last_sync: string;
    online_collection: number;
    offline_collection: number;
    created_at: string;
    updated_at: string;
}

export interface Service {
    id: string;
    machine_id: string;
    name: string;
    price: number;
    status: ServiceStatus;
    created_at: string;
    updated_at: string;
}

export interface MachineLog {
    id: string;
    machine_id: string;
    action: string;
    details: string;
    type: LogType;
    created_at: string;
}

export interface CatalogHistory {
    id: string;
    machine_id: string;
    service_id: string | null;
    action: string;
    details: string;
    user_name: string;
    type: HistoryType;
    created_at: string;
}

export interface Payment {
    id: string;
    machine_id: string;
    bill_number: string;
    amount: number;
    method: PaymentMethod;
    status: PaymentStatus;
    created_at: string;
}

// API Request/Response Types
export interface CreateMachineInput {
    name: string;
    location: string;
    status?: MachineStatus;
}

export interface UpdateMachineInput {
    name?: string;
    location?: string;
    status?: MachineStatus;
    online_collection?: number;
    offline_collection?: number;
}

export interface CreateServiceInput {
    machine_id: string;
    name: string;
    price: number;
    status?: ServiceStatus;
}

export interface UpdateServiceInput {
    name?: string;
    price?: number;
    status?: ServiceStatus;
}

export interface CreateLogInput {
    machine_id: string;
    action: string;
    details: string;
    type: LogType;
}

export interface CreateCatalogHistoryInput {
    machine_id: string;
    service_id?: string;
    action: string;
    details: string;
    user_name?: string;
    type: HistoryType;
}

export interface CreatePaymentInput {
    machine_id: string;
    bill_number: string;
    amount: number;
    method: PaymentMethod;
    status?: PaymentStatus;
}

// Extended types with relations
export interface MachineWithDetails extends Machine {
    services?: Service[];
    logs?: MachineLog[];
    catalog_history?: CatalogHistory[];
    payments?: Payment[];
}
