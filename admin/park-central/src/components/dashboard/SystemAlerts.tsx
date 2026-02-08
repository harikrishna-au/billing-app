import { AlertTriangle, CheckCircle2, XCircle, ArrowRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useNavigate } from "react-router-dom";

interface Alert {
    id: string;
    machine: string;
    message: string;
    severity: "critical" | "warning" | "info";
    time: string;
}

interface SystemAlertsProps {
    alerts?: Alert[];
}

const severityConfig = {
    critical: { icon: XCircle, color: "text-destructive", bg: "bg-destructive/10", border: "border-destructive/20" },
    warning: { icon: AlertTriangle, color: "text-amber-500", bg: "bg-amber-500/10", border: "border-amber-500/20" },
    info: { icon: CheckCircle2, color: "text-blue-500", bg: "bg-blue-500/10", border: "border-blue-500/20" },
};

const SystemAlerts = ({ alerts = [] }: SystemAlertsProps) => {
    const navigate = useNavigate();

    return (
        <div className="stat-card animate-slide-up">
            <div className="mb-6 flex items-center justify-between">
                <div>
                    <h3 className="text-lg font-semibold text-foreground">System Alerts</h3>
                    <p className="text-sm text-muted-foreground">Operational health & notifications</p>
                </div>
                <Button
                    variant="ghost"
                    size="sm"
                    className="text-primary hover:text-primary/80"
                    onClick={() => navigate('/alerts')}
                >
                    View All <ArrowRight className="h-4 w-4 ml-1" />
                </Button>
            </div>

            {alerts.length === 0 ? (
                <div className="flex items-center justify-center h-32">
                    <p className="text-muted-foreground">No alerts at this time</p>
                </div>
            ) : (
                <div className="space-y-3">
                    {alerts.map((alert) => {
                        const config = severityConfig[alert.severity];
                        const Icon = config.icon;

                        return (
                            <div
                                key={alert.id}
                                className={`flex items-start gap-3 p-3 rounded-lg border ${config.border} ${config.bg} transition-all hover:bg-opacity-70`}
                            >
                                <div className={`mt-0.5 shrink-0 ${config.color}`}>
                                    <Icon className="h-5 w-5" />
                                </div>
                                <div className="flex-1 min-w-0">
                                    <div className="flex justify-between items-start mb-1">
                                        <p className="text-sm font-semibold text-foreground truncate pr-2">{alert.machine}</p>
                                        <span className="text-xs text-muted-foreground whitespace-nowrap">{alert.time}</span>
                                    </div>
                                    <p className="text-sm text-muted-foreground leading-snug">{alert.message}</p>
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}
        </div>
    );
};

export default SystemAlerts;
