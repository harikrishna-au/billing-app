import apiClient from './client';

export interface Location {
    id: string;
    name: string;
    upi_id?: string | null;
    created_at: string;
    updated_at: string;
}

export interface LocationCreate {
    name: string;
    upi_id?: string;
}

export interface LocationUpdate {
    name?: string;
    upi_id?: string;
}

export const locationsApi = {
    async getAll(): Promise<Location[]> {
        const response = await apiClient.get<{ success: boolean; data: Location[] }>('/v1/locations');
        return response.data.data;
    },

    async create(data: LocationCreate): Promise<Location> {
        const response = await apiClient.post<{ success: boolean; data: Location }>('/v1/locations', data);
        return response.data.data;
    },

    async update(id: string, data: LocationUpdate): Promise<Location> {
        const response = await apiClient.put<{ success: boolean; data: Location }>(`/v1/locations/${id}`, data);
        return response.data.data;
    },

    async delete(id: string): Promise<void> {
        await apiClient.delete(`/v1/locations/${id}`);
    },
};
