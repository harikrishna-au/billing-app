import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts";

interface RevenueData {
  name: string;
  revenue: number;
}

interface RevenueChartProps {
  data?: RevenueData[];
}

const RevenueChart = ({ data = [] }: RevenueChartProps) => {
  return (
    <div className="stat-card animate-slide-up">
      <div className="mb-6">
        <h3 className="text-lg font-semibold text-foreground">Weekly Collections</h3>
        <p className="text-sm text-muted-foreground">Revenue across all terminals</p>
      </div>

      {data.length === 0 ? (
        <div className="h-64 flex items-center justify-center">
          <p className="text-muted-foreground">No revenue data available</p>
        </div>
      ) : (
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data}>
              <defs>
                <linearGradient id="revenueGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#10b981" stopOpacity={0.3} />
                  <stop offset="100%" stopColor="#10b981" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(222 30% 18%)" />
              <XAxis
                dataKey="name"
                stroke="hsl(215 20% 55%)"
                fontSize={12}
                tickLine={false}
                axisLine={false}
              />
              <YAxis
                stroke="hsl(215 20% 55%)"
                fontSize={12}
                tickLine={false}
                axisLine={false}
                tickFormatter={(value) => `₹${(value / 1000).toFixed(0)}k`}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "hsl(222 47% 10%)",
                  border: "1px solid hsl(222 30% 18%)",
                  borderRadius: "8px",
                  color: "hsl(210 40% 98%)",
                }}
                formatter={(value: number) => [`₹${value.toLocaleString()}`, "Collection"]}
              />
              <Area
                type="monotone"
                dataKey="revenue"
                stroke="#10b981"
                strokeWidth={2}
                fill="url(#revenueGradient)"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
};

export default RevenueChart;
