import apiClient from './client';

export interface Log {
    id: string;
    machine_id: string;
    machine_name?: string;
    action: string;
    details: string;
    type: 'login' | 'client' | 'config' | 'manager' | 'system';
    created_at: string;
}

export interface LogListResponse {
    logs: Log[];
    pagination: {
        current_page: number;
        total_pages: number;
        total_items: number;
        items_per_page: number;
    };
}

export interface CreateLogInput {
    action: string;
    details: string;
    type: 'login' | 'client' | 'config' | 'manager' | 'system';
}

export const logsApi = {
    /**
     * Get logs for a machine
     */
    async getByMachine(
        machineId: string,
        params?: {
            type?: string;
            page?: number;
            limit?: number
        }
    ): Promise<LogListResponse> {
        // Handle legacy call signature if passing just a number as second arg
        if (typeof params === 'number') {
            params = { limit: params };
        }

        console.log(`📊 Fetching logs for machine ${machineId}...`);
        const response = await apiClient.get<{ success: boolean; data: LogListResponse }>(
            `/v1/machines/${machineId}/logs`,
            { params }
        );
        return response.data.data;
    },

    /**
     * Get recent logs (global)
     */
    async getRecent(limit: number = 10, type?: string): Promise<Log[]> {
        console.log('📊 Fetching recent logs...');
        const params = { limit, type };
        const response = await apiClient.get<{ success: boolean; data: Log[] }>(
            '/v1/logs/recent',
            { params }
        );
        return response.data.data;
    },

    /**
     * Create a log entry
     */
    async create(machineId: string, data: CreateLogInput): Promise<Log> {
        console.log('📝 Creating log entry...');
        const response = await apiClient.post<{ success: boolean; data: Log }>(
            `/v1/machines/${machineId}/logs`,
            data
        );
        return response.data.data;
    }
};
