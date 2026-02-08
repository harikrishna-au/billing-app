import { supabase } from '../supabase';
import type { Machine, Payment, MachineLog } from '@/types/database';
import apiClient from './client';

export interface DashboardStats {
    totalMachines: number;
    onlineMachines: number;
    todayCollection: number;
    monthlyCollection: number;
}

export interface WeeklyRevenueData {
    name: string;
    revenue: number;
    date: string;
}

export interface SystemAlert {
    id: string;
    machine: string;
    message: string;
    severity: 'critical' | 'warning' | 'info';
    time: string;
}

// Backend API response interfaces
export interface BackendMachine {
    id: string;
    name: string;
    location: string;
    status: 'online' | 'offline' | 'maintenance';
    last_sync: string;
    online_collection: number;
    offline_collection: number;
}

export interface PaymentChartData {
    created_at: string;
    amount: number;
}

/**
 * Get all machines from backend
 */
export const getMachines = async (): Promise<BackendMachine[]> => {
    console.log('📊 Fetching machines from backend...');
    const response = await apiClient.get<{ success: boolean; data: BackendMachine[] }>('/v1/dashboard/machines');
    console.log(`✅ Fetched ${response.data.data.length} machines`);
    return response.data.data;
};

/**
 * Get payment chart data for the last 7 days from backend
 */
export const getPaymentChartData = async (): Promise<PaymentChartData[]> => {
    console.log('📊 Fetching payment chart data from backend...');
    const response = await apiClient.get<{ success: boolean; data: PaymentChartData[] }>('/v1/dashboard/payments/chart');
    console.log(`✅ Fetched ${response.data.data.length} data points`);
    return response.data.data;
};

export const dashboardApi = {
    /**
     * Get dashboard statistics from backend
     */
    async getDashboardStats(): Promise<DashboardStats> {
        console.log('📊 Fetching dashboard stats from backend...');

        const response = await apiClient.get<{
            success: boolean; data: {
                total_machines: number;
                online_machines: number;
                today_collection: number;
                monthly_collection: number;
            }
        }>('/v1/dashboard/stats');

        const data = response.data.data;

        console.log(`✅ Dashboard stats: ${data.total_machines} machines, ${data.online_machines} online`);

        return {
            totalMachines: data.total_machines,
            onlineMachines: data.online_machines,
            todayCollection: data.today_collection,
            monthlyCollection: data.monthly_collection,
        };
    },

    /**
     * Get weekly revenue data for chart from backend
     */
    async getWeeklyRevenue(): Promise<WeeklyRevenueData[]> {
        console.log('📊 Fetching weekly revenue from backend...');

        const response = await apiClient.get<{
            success: boolean; data: Array<{
                date: string;
                day_name: string;
                revenue: number;
                transaction_count: number;
            }>
        }>('/v1/dashboard/revenue/weekly');

        const result: WeeklyRevenueData[] = response.data.data.map(item => ({
            name: item.day_name,
            revenue: item.revenue,
            date: item.date,
        }));

        console.log(`✅ Fetched ${result.length} days of revenue data`);
        return result;
    },

    /**
     * Get system alerts from backend
     */
    async getSystemAlerts(): Promise<SystemAlert[]> {
        console.log('📊 Fetching system alerts from backend...');

        const response = await apiClient.get<{
            success: boolean; data: Array<{
                id: string;
                machine_id: string | null;
                machine_name: string;
                message: string;
                severity: 'critical' | 'warning' | 'info';
                created_at: string;
            }>
        }>('/v1/dashboard/alerts?limit=5');

        const alerts: SystemAlert[] = response.data.data.map(item => ({
            id: item.id,
            machine: item.machine_name,
            message: item.message,
            severity: item.severity,
            time: this.formatTimeAgo(new Date(item.created_at)),
        }));

        console.log(`✅ Fetched ${alerts.length} system alerts`);
        return alerts;
    },

    /**
     * Get alerts with filtering
     */
    async getAlerts(params?: {
        start_date?: string;
        end_date?: string;
        severity?: 'critical' | 'warning' | 'info';
    }): Promise<Array<{
        id: string;
        machine_id: string | null;
        machine_name: string;
        title: string;
        message: string;
        severity: 'critical' | 'warning' | 'info';
        created_at: string;
    }>> {
        console.log('🚨 Fetching filtered alerts...');
        const response = await apiClient.get<{
            success: boolean; data: Array<{
                id: string;
                machine_id: string | null;
                machine_name: string;
                title: string;
                message: string;
                severity: 'critical' | 'warning' | 'info';
                created_at: string;
            }>
        }>('/v1/dashboard/alerts', { params });
        return response.data.data;
    },

    /**
     * Helper function to format time ago string
     */
    formatTimeAgo(date: Date): string {
        const now = new Date();
        const diffMs = now.getTime() - date.getTime();
        const diffMins = Math.floor(diffMs / (1000 * 60));
        const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
        const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

        if (diffMins < 60) {
            return `${diffMins}m ago`;
        } else if (diffHours < 24) {
            return `${diffHours}h ago`;
        } else {
            return `${diffDays}d ago`;
        }
    },
};
