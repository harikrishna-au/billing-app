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

export interface AuditLog {
    id: string;
    actor_id: string;
    actor_username: string;
    action: string;
    target_type: string | null;
    target_id: string | null;
    details: string | null;
    created_at: string | null;
}

export interface CreateAdminResult {
    id: string;
    username: string;
    email: string;
    clerk_ready: boolean;
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

    createAdmin: async (data: { username: string; email: string; phone?: string; password: string }): Promise<CreateAdminResult> => {
        const res = await apiClient.post<{ success: boolean; data: CreateAdminResult }>(`${BASE}/admins`, data);
        return res.data.data;
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

    listAuditLogs: async (params?: { action?: string; page?: number; limit?: number }): Promise<{ logs: AuditLog[]; pagination: { total: number; page: number; limit: number } }> => {
        const query = new URLSearchParams();
        if (params?.action) query.set('action', params.action);
        if (params?.page) query.set('page', String(params.page));
        if (params?.limit) query.set('limit', String(params.limit));
        const qs = query.toString() ? `?${query.toString()}` : '';
        const res = await apiClient.get<{ success: boolean; data: { logs: AuditLog[]; pagination: { total: number; page: number; limit: number } } }>(`${BASE}/audit-logs${qs}`);
        return res.data.data;
    },
};

export const machineUpiRequestApi = {
    submit: async (machineId: string, newUpiId: string): Promise<void> => {
        await apiClient.post(`/v1/machines/${machineId}/upi-request`, { new_upi_id: newUpiId });
    },
};
