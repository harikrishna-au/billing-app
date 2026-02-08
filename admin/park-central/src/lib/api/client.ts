import axios, { AxiosInstance, AxiosError, InternalAxiosRequestConfig } from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

// Create axios instance
const apiClient: AxiosInstance = axios.create({
    baseURL: API_URL,
    headers: {
        'Content-Type': 'application/json',
    },
    timeout: 60000,  // Increased from 10s to 60s for slow bcrypt operations
});

// Request interceptor - Add auth token to requests
apiClient.interceptors.request.use(
    (config: InternalAxiosRequestConfig) => {
        const token = localStorage.getItem('access_token');

        if (token && config.headers) {
            config.headers.Authorization = `Bearer ${token}`;
        }

        // Log request
        console.log(`🔵 API Request: ${config.method?.toUpperCase()} ${config.url}`);

        return config;
    },
    (error) => {
        console.error('❌ Request Error:', error);
        return Promise.reject(error);
    }
);

// Response interceptor - Handle token refresh on 401
apiClient.interceptors.response.use(
    (response) => {
        // Log successful response
        console.log(`🟢 API Response: ${response.config.method?.toUpperCase()} ${response.config.url} - ${response.status}`);
        return response;
    },
    async (error: AxiosError) => {
        const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

        // Log error
        console.error(`🔴 API Error: ${error.config?.method?.toUpperCase()} ${error.config?.url} - ${error.response?.status}`);

        // If 401 and we haven't retried yet, try to refresh token
        if (error.response?.status === 401 && !originalRequest._retry) {
            originalRequest._retry = true;

            try {
                const refreshToken = localStorage.getItem('refresh_token');

                if (!refreshToken) {
                    // No refresh token, redirect to login
                    console.warn('⚠️  No refresh token available, redirecting to login');
                    localStorage.clear();
                    window.location.href = '/login';
                    return Promise.reject(error);
                }

                console.log('🔄 Attempting token refresh...');

                // Call refresh endpoint
                const response = await axios.post(`${API_URL}/v1/auth/refresh`, {
                    refresh_token: refreshToken
                });

                const { access_token } = response.data.data;

                // Store new token
                localStorage.setItem('access_token', access_token);

                console.log('✅ Token refreshed successfully');

                // Retry original request with new token
                if (originalRequest.headers) {
                    originalRequest.headers.Authorization = `Bearer ${access_token}`;
                }

                return apiClient(originalRequest);
            } catch (refreshError) {
                console.error('❌ Token refresh failed:', refreshError);
                // Refresh failed, clear tokens and redirect to login
                localStorage.clear();
                window.location.href = '/login';
                return Promise.reject(refreshError);
            }
        }

        return Promise.reject(error);
    }
);

export default apiClient;
