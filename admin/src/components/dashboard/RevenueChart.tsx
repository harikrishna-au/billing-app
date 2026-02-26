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
        <h3 className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">Weekly Collections</h3>
        <p className="mt-1 text-base font-semibold text-foreground">Revenue Overview</p>
      </div>

      {data.length === 0 ? (
        <div className="h-64 flex items-center justify-center">
          <p className="text-sm text-muted-foreground">No revenue data available</p>
        </div>
      ) : (
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data} margin={{ top: 4, right: 4, left: 0, bottom: 0 }}>
              <defs>
                <linearGradient id="revenueGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="hsl(248 90% 66%)" stopOpacity={0.25} />
                  <stop offset="100%" stopColor="hsl(248 90% 66%)" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid
                strokeDasharray="3 3"
                stroke="hsl(224 14% 13%)"
                vertical={false}
              />
              <XAxis
                dataKey="name"
                stroke="hsl(220 13% 25%)"
                tick={{ fill: "hsl(220 13% 48%)", fontSize: 11, fontFamily: "Outfit" }}
                tickLine={false}
                axisLine={false}
              />
              <YAxis
                stroke="hsl(220 13% 25%)"
                tick={{ fill: "hsl(220 13% 48%)", fontSize: 11, fontFamily: "JetBrains Mono" }}
                tickLine={false}
                axisLine={false}
                tickFormatter={(value) => `₹${(value / 1000).toFixed(0)}k`}
                width={52}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "hsl(224 14% 9%)",
                  border: "1px solid hsl(224 14% 16%)",
                  borderRadius: "10px",
                  color: "hsl(220 13% 93%)",
                  fontSize: "13px",
                  fontFamily: "Outfit",
                  boxShadow: "0 8px 32px -8px hsl(0 0% 0% / 0.5)",
                }}
                cursor={{ stroke: "hsl(248 90% 66% / 0.3)", strokeWidth: 1 }}
                formatter={(value: number) => [`₹${value.toLocaleString("en-IN")}`, "Collection"]}
              />
              <Area
                type="monotone"
                dataKey="revenue"
                stroke="hsl(248 90% 66%)"
                strokeWidth={2}
                fill="url(#revenueGradient)"
                dot={false}
                activeDot={{ r: 4, fill: "hsl(248 90% 66%)", stroke: "hsl(224 14% 9%)", strokeWidth: 2 }}
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
};

export default RevenueChart;
