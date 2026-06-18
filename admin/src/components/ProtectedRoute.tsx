import { Navigate } from 'react-router-dom';

interface ProtectedRouteProps {
  children: React.ReactNode;
  superadminOnly?: boolean;
}

export const ProtectedRoute = ({ children, superadminOnly = false }: ProtectedRouteProps) => {
  const token = localStorage.getItem('access_token');
  const userStr = localStorage.getItem('user');

  if (!token) {
    return <Navigate to="/login" replace />;
  }

  let user: { role?: string } | null = null;
  try {
    user = userStr ? JSON.parse(userStr) : null;
  } catch {
    return <Navigate to="/login" replace />;
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (superadminOnly && user.role !== 'superadmin') {
    return <Navigate to="/dashboard" replace />;
  }

  if (!superadminOnly && user.role === 'superadmin') {
    return <Navigate to="/superadmin" replace />;
  }

  return <>{children}</>;
};
