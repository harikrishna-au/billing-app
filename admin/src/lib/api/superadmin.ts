import apiClient from './client';

export interface AdminSummary {
    id: string;
    username: string;
    email: string;
    phone: string | null;
    is_active: string;
    machine_count: number;
    created_at: string | null;
}

export interface AdminDetail extends AdminSummary {
    pending_upi_requests: number;
    machines: {
        id: string;
        name: string;
        location: string;
        status: string;
        upi_id: string | null;
        last_sync: string | null;
    }[];
}

export interface SuperMachine {
    id: string;
    name: string;
    location: string;
    username: string;
    status: string;
    upi_id: string | null;
    admin: string;
    admin_id: string;
    last_sync: string | null;
    created_at: string | null;
}

export interface UpiRequest {
    id: string;
    machine_id: string;
    machine_name: string;
    requested_by_id: string;
    requested_by: string;
    old_upi_id: string | null;
    new_upi_id: string;
    status: 'pending' | 'approved' | 'rejected';
    superadmin_note: string | null;
    created_at: string | null;
    resolved_at: string | null;
}

const BASE = '/v1/superadmin';

export const superadminApi = {
    listAdmins: async (): Promise<AdminSummary[]> => {
        const res = await apiClient.get<{ success: boolean; data: { admins: AdminSummary[] } }>(`${BASE}/admins`);
        return res.data.data.admins;
    },

    getAdmin: async (adminId: string): Promise<AdminDetail> => {
        const res = await apiClient.get<{ success: boolean; data: AdminDetail }>(`${BASE}/admins/${adminId}`);
        return res.data.data;
    },

    createAdmin: async (data: { username: string; email: string; phone?: string; password: string }): Promise<void> => {
        await apiClient.post(`${BASE}/admins`, data);
    },

    toggleAdminStatus: async (adminId: string, isActive: boolean): Promise<void> => {
        await apiClient.patch(`${BASE}/admins/${adminId}/status`, { is_active: isActive ? 'true' : 'false' });
    },

    listMachines: async (): Promise<SuperMachine[]> => {
        const res = await apiClient.get<{ success: boolean; data: { machines: SuperMachine[] } }>(`${BASE}/machines`);
        return res.data.data.machines;
    },

    listUpiRequests: async (status?: string): Promise<UpiRequest[]> => {
        const params = status ? `?status=${status}` : '';
        const res = await apiClient.get<{ success: boolean; data: { requests: UpiRequest[] } }>(`${BASE}/upi-requests${params}`);
        return res.data.data.requests;
    },

    approveUpiRequest: async (requestId: string): Promise<void> => {
        await apiClient.post(`${BASE}/upi-requests/${requestId}/approve`);
    },

    rejectUpiRequest: async (requestId: string, note?: string): Promise<void> => {
        await apiClient.post(`${BASE}/upi-requests/${requestId}/reject`, { note: note ?? '' });
    },
};

export const machineUpiRequestApi = {
    submit: async (machineId: string, newUpiId: string): Promise<void> => {
        await apiClient.post(`/v1/machines/${machineId}/upi-request`, { new_upi_id: newUpiId });
    },
};
