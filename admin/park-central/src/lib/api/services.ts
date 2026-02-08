import apiClient from './client';

export interface Service {
    id: string;
    machine_id: string;
    name: string;
    price: number;
    status: 'active' | 'inactive';
    created_at: string;
    updated_at: string;
}

export interface CreateServiceInput {
    machine_id: string; // Used in URL, not body
    name: string;
    price: number;
    status?: 'active' | 'inactive';
}

export interface UpdateServiceInput {
    name?: string;
    price?: number;
    status?: 'active' | 'inactive';
}

export interface ServiceResponse {
    success: boolean;
    data: Service | Service[];
}

export const servicesApi = {
    /**
     * Get all services for a machine
     */
    async getByMachine(machineId: string): Promise<Service[]> {
        console.log(`📊 Fetching services for machine ${machineId}...`);
        const response = await apiClient.get<{ success: boolean; data: Service[] }>(`/v1/machines/${machineId}/services`);
        console.log(`✅ Fetched ${response.data.data.length} services`);
        return response.data.data;
    },

    /**
     * Get a single service by ID
     */
    async getById(id: string): Promise<Service> {
        console.log(`📊 Fetching service ${id}...`);
        const response = await apiClient.get<{ success: boolean; data: Service }>(`/v1/services/${id}`);
        return response.data.data;
    },

    /**
     * Create a new service
     */
    async create(input: CreateServiceInput): Promise<Service> {
        console.log(`📝 Creating service: ${input.name}`);
        const { machine_id, ...data } = input;
        const response = await apiClient.post<{ success: boolean; data: Service }>(
            `/v1/machines/${machine_id}/services`,
            data
        );
        console.log(`✅ Created service: ${response.data.data.name}`);
        return response.data.data;
    },

    /**
     * Update a service
     */
    async update(id: string, input: UpdateServiceInput): Promise<Service> {
        console.log(`📝 Updating service ${id}...`);
        const response = await apiClient.put<{ success: boolean; data: Service }>(
            `/v1/services/${id}`,
            input
        );
        console.log(`✅ Updated service: ${response.data.data.name}`);
        return response.data.data;
    },

    /**
     * Delete a service
     */
    async delete(id: string): Promise<void> {
        console.log(`🗑️ Deleting service ${id}...`);
        await apiClient.delete(`/v1/services/${id}`);
        console.log(`✅ Service deleted`);
    },

    /**
     * Get active services for a machine
     */
    async getActiveByMachine(machineId: string): Promise<Service[]> {
        console.log(`📊 Fetching active services for machine ${machineId}...`);
        const response = await apiClient.get<{ success: boolean; data: Service[] }>(
            `/v1/machines/${machineId}/services`,
            { params: { status: 'active' } }
        );
        return response.data.data;
    },
};
