import apiClient from './client';

export interface Payment {
    id: string;
    machine_id: string;
    machine_name: string;
    bill_number: string;
    amount: number;
    method: 'UPI' | 'Card' | 'Cash';
    status: 'success' | 'pending' | 'failed';
    created_at: string;
}

export interface PaymentSummary {
    total_amount: number;
    total_count: number;
    upi_amount: number;
    card_amount: number;
    cash_amount: number;
    success_count: number;
    pending_count: number;
    failed_count: number;
}

export interface PaymentListResponse {
    payments: Payment[];
    pagination: {
        current_page: number;
        total_pages: number;
        total_items: number;
        items_per_page: number;
    };
    summary: PaymentSummary;
}

export interface CreatePaymentInput {
    machine_id: string;
    bill_number: string;
    amount: number;
    method: 'UPI' | 'Card' | 'Cash';
    status?: 'success' | 'pending' | 'failed';
}

export const paymentsApi = {
    /**
     * Get payments for a machine
     */
    async getByMachine(
        machineId: string,
        params?: {
            period?: 'day' | 'week' | 'month' | 'year';
            method?: 'UPI' | 'Card' | 'Cash';
            status?: 'success' | 'pending' | 'failed';
            start_date?: string;
            end_date?: string;
            page?: number;
            limit?: number;
        }
    ): Promise<PaymentListResponse> {
        console.log(`📊 Fetching payments for machine ${machineId}...`);
        const response = await apiClient.get<{ success: boolean; data: PaymentListResponse }>(
            `/v1/machines/${machineId}/payments`,
            { params }
        );
        return response.data.data;
    },

    /**
     * Get all payments
     */
    async getAll(
        params?: {
            period?: 'day' | 'week' | 'month' | 'year';
            method?: 'UPI' | 'Card' | 'Cash';
            status?: 'success' | 'pending' | 'failed';
            start_date?: string;
            end_date?: string;
            machine_id?: string;
            page?: number;
            limit?: number;
        }
    ): Promise<PaymentListResponse> {
        console.log('📊 Fetching all payments...');
        const response = await apiClient.get<{ success: boolean; data: PaymentListResponse }>(
            '/v1/payments',
            { params }
        );
        return response.data.data;
    },

    /**
     * Get a single payment
     */
    async getById(id: string): Promise<Payment> {
        const response = await apiClient.get<{ success: boolean; data: Payment }>(`/v1/payments/${id}`);
        return response.data.data;
    },

    /**
     * Create a new payment
     */
    async create(input: CreatePaymentInput): Promise<Payment> {
        console.log('📝 Creating payment...');
        const response = await apiClient.post<{ success: boolean; data: Payment }>('/v1/payments', input);
        console.log(`✅ Created payment: ${response.data.data.bill_number}`);
        return response.data.data;
    },

    /**
     * Update a payment
     */
    async update(id: string, input: Partial<CreatePaymentInput>): Promise<Payment> {
        const response = await apiClient.put<{ success: boolean; data: Payment }>(`/v1/payments/${id}`, input);
        return response.data.data;
    },

    /**
     * Delete a payment
     */
    async delete(id: string): Promise<void> {
        await apiClient.delete(`/v1/payments/${id}`);
    },
};
