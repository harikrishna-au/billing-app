import apiClient from './client';

export interface RevenuePeriod {
    period: string;
    revenue: number;
    transaction_count: number;
}

export interface TopMachine {
    machine_id: string;
    machine_name: string;
    revenue: number;
    transaction_count: number;
}

export interface RevenueAnalytics {
    total_revenue: number;
    total_transactions: number;
    average_transaction: number;
    revenue_by_period: RevenuePeriod[];
    revenue_by_method: Record<string, number>;
    top_machines: TopMachine[];
}

export interface MachinePerformance {
    machine_id: string;
    machine_name: string;
    status: string;
    revenue: number;
    transaction_count: number;
    uptime_percentage: number;
    last_sync: string | null;
    average_transaction: number;
}

export const analyticsApi = {
    /**
     * Get revenue analytics
     */
    async getRevenueAnalytics(params?: {
        period?: 'day' | 'week' | 'month' | 'year';
        start_date?: string;
        end_date?: string;
        machine_id?: string;
        group_by?: 'day' | 'week' | 'month';
    }): Promise<RevenueAnalytics> {
        console.log('📊 Fetching revenue analytics...');
        const response = await apiClient.get<{ success: boolean; data: RevenueAnalytics }>('/v1/analytics/revenue', { params });
        return response.data.data;
    },

    /**
     * Get machine performance metrics
     */
    async getMachinePerformance(params?: {
        period?: 'day' | 'week' | 'month';
        sort_by?: 'revenue' | 'transactions' | 'uptime';
    }): Promise<MachinePerformance[]> {
        console.log('📊 Fetching machine performance...');
        const response = await apiClient.get<{ success: boolean; data: MachinePerformance[] }>('/v1/analytics/machines/performance', { params });
        return response.data.data;
    },

    /**
     * Export data
     */
    async exportData(
        type: 'payments' | 'machines' | 'services' | 'logs',
        params?: {
            format?: 'csv' | 'excel' | 'json';
            start_date?: string;
            end_date?: string;
            machine_id?: string;
        }
    ): Promise<Blob> {
        console.log(`📥 Exporting ${type} data...`);
        const response = await apiClient.get(`/v1/analytics/export/${type}`, {
            params,
            responseType: 'blob'
        });
        return response.data;
    },
};
