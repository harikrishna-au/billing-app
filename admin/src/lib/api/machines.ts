/**
 * API client for machine operations
 */
import apiClient from './client';

export interface MachineCreate {
    name: string;
    location: string;
    username_prefix: string;
    password: string;
}

export interface MachineUpdate {
    name?: string;
    location?: string;
    username?: string;
    password?: string;
    status?: 'online' | 'offline' | 'maintenance';
}

export interface Machine {
    id: string;
    name: string;
    location: string;
    username: string;
    status: 'online' | 'offline' | 'maintenance';
    last_sync: string | null;
    online_collection: number;
    offline_collection: number;
    created_at: string;
    updated_at: string;
}

export interface MachinesListResponse {
    machines: Machine[];
    pagination: {
        current_page: number;
        total_pages: number;
        total_items: number;
        items_per_page: number;
    };
}

export const machinesApi = {
    /**
     * Get all machines with pagination and filtering
     */
    async getAll(params?: {
        page?: number;
        limit?: number;
        status?: 'online' | 'offline' | 'maintenance';
        search?: string;
    }): Promise<MachinesListResponse> {
        console.log('📊 Fetching machines from backend...', params);
        const response = await apiClient.get<{ success: boolean; data: MachinesListResponse }>('/v1/machines', { params });
        console.log(`✅ Fetched ${response.data.data.machines.length} machines`);
        return response.data.data;
    },

    /**
     * Get a single machine by ID
     */
    async getById(id: string): Promise<Machine> {
        console.log(`📊 Fetching machine ${id}...`);
        const response = await apiClient.get<{ success: boolean; data: Machine }>(`/v1/machines/${id}`);
        console.log(`✅ Fetched machine: ${response.data.data.name}`);
        return response.data.data;
    },

    /**
     * Create a new machine
     */
    async create(data: MachineCreate): Promise<Machine> {
        console.log('📝 Creating new machine:', data.name);
        const response = await apiClient.post<{ success: boolean; data: Machine }>('/v1/machines', data);
        console.log(`✅ Created machine: ${response.data.data.name} (${response.data.data.username})`);
        return response.data.data;
    },

    /**
     * Update an existing machine
     */
    async update(id: string, data: MachineUpdate): Promise<Machine> {
        console.log(`📝 Updating machine ${id}...`);
        const response = await apiClient.put<{ success: boolean; data: Machine }>(`/v1/machines/${id}`, data);
        console.log(`✅ Updated machine: ${response.data.data.name}`);
        return response.data.data;
    },

    /**
     * Delete a machine
     */
    async delete(id: string): Promise<void> {
        console.log(`🗑️ Deleting machine ${id}...`);
        await apiClient.delete(`/v1/machines/${id}`);
        console.log(`✅ Machine deleted`);
    }
};
