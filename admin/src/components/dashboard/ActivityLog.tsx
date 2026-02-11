import { User, Building2, LogIn, Settings, Shield } from "lucide-react";

export interface LogEntry {
  id: string;
  action: string;
  details: string;
  timestamp: string;
  type: "login" | "client" | "config" | "manager" | "system";
}

interface ActivityLogProps {
  logs: LogEntry[];
  title?: string;
}

const iconMap = {
  login: LogIn,
  client: Building2,
  config: Settings,
  manager: User,
  system: Shield,
};

const colorMap = {
  login: "bg-chart-1/10 text-chart-1",
  client: "bg-chart-2/10 text-chart-2",
  config: "bg-chart-3/10 text-chart-3",
  manager: "bg-chart-4/10 text-chart-4",
  system: "bg-chart-5/10 text-chart-5",
};

const ActivityLog = ({ logs, title = "Activity Log" }: ActivityLogProps) => {
  return (
    <div className="stat-card animate-slide-up">
      <div className="mb-6 flex items-center justify-between">
        <h3 className="text-lg font-semibold text-foreground">{title}</h3>
        <span className="text-sm text-muted-foreground">{logs.length} entries</span>
      </div>

      <div className="space-y-3 max-h-[400px] overflow-y-auto pr-2">
        {logs.length === 0 ? (
          <p className="text-center text-muted-foreground py-8">No activity recorded</p>
        ) : (
          logs.map((log) => {
            const Icon = iconMap[log.type];
            const colorClass = colorMap[log.type];
            return (
              <div
                key={log.id}
                className="flex items-start gap-3 py-3 border-b border-border/30 last:border-0"
              >
                <div className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-lg ${colorClass}`}>
                  <Icon className="h-4 w-4" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-foreground">{log.action}</p>
                  <p className="text-xs text-muted-foreground truncate">{log.details}</p>
                </div>
                <span className="text-xs text-muted-foreground whitespace-nowrap">
                  {log.timestamp}
                </span>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};

export default ActivityLog;
