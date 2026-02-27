/**
 * API client for bill configuration operations
 */
import apiClient from './client';

export interface BillConfig {
    id: string;
    machine_id: string;
    org_name: string;
    tagline: string | null;
    logo_url: string | null;
    unit_name: string | null;
    territory: string | null;
    gst_number: string | null;
    pos_id: string | null;
    cgst_percent: number;
    sgst_percent: number;
    footer_message: string | null;
    website: string | null;
    toll_free: string | null;
    created_at: string;
    updated_at: string;
}

export type BillConfigUpdate = Partial<Omit<BillConfig, 'id' | 'machine_id' | 'created_at' | 'updated_at'>>;

export const configApi = {
    /**
     * Fetch bill configuration for a machine. Returns null if not configured yet.
     */
    async getByMachine(machineId: string): Promise<BillConfig | null> {
        const response = await apiClient.get<{ success: boolean; data: BillConfig | null }>(
            `/v1/config/machine/${machineId}`
        );
        return response.data.data;
    },

    /**
     * Create or update (upsert) bill configuration for a machine.
     */
    async upsert(machineId: string, data: BillConfigUpdate): Promise<BillConfig> {
        const response = await apiClient.put<{ success: boolean; data: BillConfig }>(
            `/v1/config/machine/${machineId}`,
            data
        );
        return response.data.data;
    },
};
