import apiClient from './client';

export interface LoginCredentials {
    username: string;
    password: string;
}

export interface LoginResponse {
    success: boolean;
    data: {
        user: {
            id: string;
            username: string;
            email: string;
            role: string;
            created_at: string;
        };
        token: string;
        refresh_token: string;
        expires_in: number;
    };
}

export interface RefreshTokenResponse {
    success: boolean;
    data: {
        access_token: string;
        token_type: string;
        expires_in: number;
    };
}

export interface UserResponse {
    success: boolean;
    data: {
        id: string;
        username: string;
        email: string;
        role: string;
        created_at: string;
    };
}

/**
 * Login with username and password
 */
export const login = async (credentials: LoginCredentials): Promise<LoginResponse> => {
    console.log(`🔐 Attempting login for user: ${credentials.username}`);

    const response = await apiClient.post<LoginResponse>('/v1/auth/login', credentials);

    // Store tokens
    if (response.data.success) {
        localStorage.setItem('access_token', response.data.data.token);
        localStorage.setItem('refresh_token', response.data.data.refresh_token);
        localStorage.setItem('user', JSON.stringify(response.data.data.user));

        console.log(`✅ Login successful for user: ${credentials.username}`);
    }

    return response.data;
};

/**
 * Logout current user
 */
export const logout = async (): Promise<void> => {
    console.log('👋 Logging out user...');

    try {
        await apiClient.post('/v1/auth/logout');
    } catch (error) {
        console.error('⚠️  Logout request failed, clearing local data anyway', error);
    }

    // Clear all stored data
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('user');

    console.log('✅ Logout complete, tokens cleared');
};

/**
 * Refresh access token
 */
export const refreshToken = async (): Promise<string> => {
    const refreshToken = localStorage.getItem('refresh_token');

    if (!refreshToken) {
        throw new Error('No refresh token available');
    }

    console.log('🔄 Refreshing access token...');

    const response = await apiClient.post<RefreshTokenResponse>('/v1/auth/refresh', {
        refresh_token: refreshToken
    });

    const newToken = response.data.data.access_token;
    localStorage.setItem('access_token', newToken);

    console.log('✅ Access token refreshed');

    return newToken;
};

/**
 * Get current user information
 */
export const getCurrentUser = async (): Promise<UserResponse['data']> => {
    console.log('👤 Fetching current user info...');

    const response = await apiClient.get<UserResponse>('/v1/auth/me');

    // Update stored user data
    localStorage.setItem('user', JSON.stringify(response.data.data));

    console.log(`✅ Current user: ${response.data.data.username}`);

    return response.data.data;
};

/**
 * Check if user is authenticated
 */
export const isAuthenticated = (): boolean => {
    const token = localStorage.getItem('access_token');
    return !!token;
};

/**
 * Get stored user data
 */
export const getStoredUser = () => {
    const userStr = localStorage.getItem('user');
    return userStr ? JSON.parse(userStr) : null;
};
