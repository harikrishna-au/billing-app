import { useState } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Button } from "@/components/ui/button";
import { ArrowLeft, CalendarRange, CreditCard, DollarSign, Download, Loader2, X } from "lucide-react";
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip, Legend } from "recharts";
import { paymentsApi, machinesApi, analyticsApi } from "@/lib/api";
import {
    Breadcrumb,
    BreadcrumbItem,
    BreadcrumbLink,
    BreadcrumbList,
    BreadcrumbPage,
    BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";

type PeriodMode = "day" | "week" | "month" | "range";

const PERIOD_TABS: { key: Exclude<PeriodMode, "range">; label: string }[] = [
    { key: "day", label: "Day" },
    { key: "week", label: "Week" },
    { key: "month", label: "Month" },
];

const fmtDate = (iso: string) =>
    new Date(iso + "T00:00:00").toLocaleDateString("en-IN", {
        day: "2-digit",
        month: "short",
        year: "numeric",
    });

const MachinePayments = () => {
    const navigate = useNavigate();
    const { id } = useParams();
    const today = new Date().toISOString().split("T")[0];

    const [mode, setMode] = useState<PeriodMode>("day");
    const [fromDate, setFromDate] = useState<string>("");
    const [toDate, setToDate] = useState<string>("");
    const [isExporting, setIsExporting] = useState(false);

    // A custom range is only "active" once both ends are picked.
    const rangeActive = mode === "range" && !!fromDate && !!toDate;

    const periodLabel = rangeActive
        ? `${fmtDate(fromDate)} → ${fmtDate(toDate)}`
        : mode.charAt(0).toUpperCase() + mode.slice(1);

    const rangeParams = rangeActive
        ? { start_date: `${fromDate}T00:00:00Z`, end_date: `${toDate}T23:59:59Z` }
        : undefined;

    const handleExport = async () => {
        setIsExporting(true);
        try {
            const blob = await analyticsApi.exportData("payments", {
                machine_id: id,
                ...(rangeParams ?? {}),
            });
            const url = URL.createObjectURL(blob);
            const a = document.createElement("a");
            a.href = url;
            a.download = rangeActive
                ? `payments_${id}_${fromDate}_to_${toDate}.csv`
                : `payments_${id}_${mode}.csv`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        } catch (e) {
            console.error("Export failed", e);
        } finally {
            setIsExporting(false);
        }
    };

    // Fetch machine data
    const { data: machine } = useQuery({
        queryKey: ["machine", id],
        queryFn: () => machinesApi.getById(id!),
        enabled: !!id,
    });

    // Fetch payment stats
    const { data: response, isLoading, isFetching } = useQuery({
        queryKey: ["payments", id, mode, fromDate, toDate],
        queryFn: () =>
            rangeActive
                ? paymentsApi.getByMachine(id!, rangeParams)
                : paymentsApi.getByMachine(id!, { period: mode as "day" | "week" | "month" }),
        enabled: !!id && (mode !== "range" || rangeActive),
    });

    const summary = response?.summary;
    const onlineAmount = (summary?.upi_amount || 0) + (summary?.card_amount || 0);
    const offlineAmount = summary?.cash_amount || 0;

    const pieData = [
        { name: "Online (UPI/Card)", value: onlineAmount, color: "#10b981" },
        { name: "Offline (Cash)", value: offlineAmount, color: "#f59e0b" },
    ];

    const clearRange = () => {
        setFromDate("");
        setToDate("");
        setMode("day");
    };

    return (
        <DashboardLayout>
            <div className="space-y-6">
                {/* Header */}
                <div className="animate-fade-in">
                    <div className="mb-4 -ml-1">
                        <Breadcrumb>
                            <BreadcrumbList>
                                <BreadcrumbItem>
                                    <BreadcrumbLink asChild>
                                        <Link to="/dashboard">Home</Link>
                                    </BreadcrumbLink>
                                </BreadcrumbItem>
                                <BreadcrumbSeparator />
                                <BreadcrumbItem>
                                    <BreadcrumbLink asChild>
                                        <Link to="/clients">Blaze Machines</Link>
                                    </BreadcrumbLink>
                                </BreadcrumbItem>
                                <BreadcrumbSeparator />
                                <BreadcrumbItem>
                                    <BreadcrumbLink asChild>
                                        <Link to={`/clients/${id}`}>{machine?.name || "Unknown Machine"}</Link>
                                    </BreadcrumbLink>
                                </BreadcrumbItem>
                                <BreadcrumbSeparator />
                                <BreadcrumbItem>
                                    <BreadcrumbPage>Payments</BreadcrumbPage>
                                </BreadcrumbItem>
                            </BreadcrumbList>
                        </Breadcrumb>
                    </div>

                    <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                        <div className="flex items-center gap-3">
                            <button
                                onClick={() => navigate(-1)}
                                className="flex h-9 w-9 items-center justify-center rounded-lg border border-border/60 bg-secondary/40 text-muted-foreground transition-all hover:text-foreground hover:border-border"
                                aria-label="Go back"
                            >
                                <ArrowLeft className="h-4 w-4" />
                            </button>
                            <div>
                                <h1 className="text-2xl font-bold text-foreground">Payments Analysis</h1>
                                <p className="text-sm text-muted-foreground">
                                    {machine?.name ? `${machine.name} · ` : ""}Showing {periodLabel}
                                    {isFetching && !isLoading && (
                                        <Loader2 className="ml-2 inline h-3 w-3 animate-spin text-primary" />
                                    )}
                                </p>
                            </div>
                        </div>

                        {/* Filters */}
                        <div className="flex flex-wrap items-center gap-2">
                            {/* Quick period tabs */}
                            <div className="segmented">
                                {PERIOD_TABS.map((tab) => (
                                    <button
                                        key={tab.key}
                                        onClick={() => {
                                            setMode(tab.key);
                                            setFromDate("");
                                            setToDate("");
                                        }}
                                        className={`segmented-item ${mode === tab.key ? "active" : ""}`}
                                    >
                                        {tab.label}
                                    </button>
                                ))}
                            </div>

                            {/* From → To range */}
                            <div
                                className={`date-field ${rangeActive ? "border-primary/60" : ""}`}
                                title="Filter bills between two dates"
                            >
                                <CalendarRange
                                    className={`h-4 w-4 shrink-0 ${rangeActive ? "text-primary" : "text-muted-foreground"}`}
                                />
                                <input
                                    type="date"
                                    aria-label="From date"
                                    max={toDate || today}
                                    value={fromDate}
                                    onChange={(e) => {
                                        setFromDate(e.target.value);
                                        setMode("range");
                                    }}
                                    className="w-[112px]"
                                />
                                <span className="text-muted-foreground/60">→</span>
                                <input
                                    type="date"
                                    aria-label="To date"
                                    min={fromDate || undefined}
                                    max={today}
                                    value={toDate}
                                    onChange={(e) => {
                                        setToDate(e.target.value);
                                        setMode("range");
                                    }}
                                    className="w-[112px]"
                                />
                                {(fromDate || toDate) && (
                                    <button
                                        onClick={clearRange}
                                        className="ml-0.5 rounded-md p-0.5 text-muted-foreground transition-colors hover:bg-secondary hover:text-foreground"
                                        aria-label="Clear date range"
                                    >
                                        <X className="h-3.5 w-3.5" />
                                    </button>
                                )}
                            </div>

                            <Button variant="outline" size="sm" onClick={handleExport} disabled={isExporting}>
                                {isExporting ? (
                                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                                ) : (
                                    <Download className="h-4 w-4 mr-2" />
                                )}
                                Export
                            </Button>
                        </div>
                    </div>

                    {mode === "range" && !rangeActive && (
                        <p className="mt-3 text-xs text-amber-500/90">
                            Pick both a “From” and “To” date to view bills for that range.
                        </p>
                    )}
                </div>

                {isLoading ? (
                    <PaymentsSkeleton />
                ) : (
                    <>
                        {/* Analytics Section */}
                        <div className="grid gap-6 md:grid-cols-2 animate-slide-up">
                            {/* Pie Chart */}
                            <div className="stat-card flex flex-col items-center justify-center min-h-[300px]">
                                <h3 className="text-lg font-semibold text-foreground mb-4 w-full text-left">
                                    Collection Split
                                </h3>
                                <div className="h-64 w-full">
                                    <ResponsiveContainer width="100%" height="100%">
                                        <PieChart>
                                            <Pie
                                                data={pieData}
                                                cx="50%"
                                                cy="50%"
                                                innerRadius={60}
                                                outerRadius={80}
                                                paddingAngle={5}
                                                dataKey="value"
                                            >
                                                {pieData.map((entry, index) => (
                                                    <Cell key={`cell-${index}`} fill={entry.color} strokeWidth={0} />
                                                ))}
                                            </Pie>
                                            <Tooltip
                                                contentStyle={{
                                                    backgroundColor: "hsl(224 14% 9%)",
                                                    borderColor: "hsl(224 14% 16%)",
                                                    color: "hsl(220 13% 93%)",
                                                    borderRadius: "10px",
                                                    fontFamily: "Outfit",
                                                    fontSize: "13px",
                                                }}
                                                formatter={(value: number) => [`₹${value.toLocaleString()}`, "Amount"]}
                                            />
                                            <Legend verticalAlign="bottom" height={36} />
                                        </PieChart>
                                    </ResponsiveContainer>
                                </div>
                            </div>

                            {/* Summary Stats */}
                            <div className="grid gap-4">
                                <div className="stat-card flex flex-col justify-center">
                                    <span className="text-sm text-muted-foreground">Total Collections ({periodLabel})</span>
                                    <span className="text-4xl font-bold text-foreground mt-2">
                                        ₹{summary?.total_amount.toLocaleString() || 0}
                                    </span>
                                    <span className="text-xs text-muted-foreground mt-1">
                                        {summary?.total_count || 0} bill{(summary?.total_count || 0) === 1 ? "" : "s"}
                                    </span>
                                </div>
                                <div className="grid grid-cols-2 gap-4">
                                    <div className="stat-card bg-emerald-500/10 border-emerald-500/20">
                                        <div className="flex items-center gap-2 mb-2">
                                            <CreditCard className="h-4 w-4 text-emerald-500" />
                                            <span className="text-sm font-medium text-emerald-500">Online</span>
                                        </div>
                                        <span className="text-2xl font-bold text-foreground">
                                            ₹{onlineAmount.toLocaleString()}
                                        </span>
                                        <p className="text-xs text-muted-foreground mt-1">UPI, Credit/Debit Cards</p>
                                    </div>
                                    <div className="stat-card bg-amber-500/10 border-amber-500/20">
                                        <div className="flex items-center gap-2 mb-2">
                                            <DollarSign className="h-4 w-4 text-amber-500" />
                                            <span className="text-sm font-medium text-amber-500">Offline</span>
                                        </div>
                                        <span className="text-2xl font-bold text-foreground">
                                            ₹{offlineAmount.toLocaleString()}
                                        </span>
                                        <p className="text-xs text-muted-foreground mt-1">Cash Transactions</p>
                                    </div>
                                </div>
                            </div>
                        </div>

                        {/* Transactions Table */}
                        <div className="stat-card animate-slide-up">
                            <div className="flex items-center justify-between mb-6">
                                <div>
                                    <h3 className="text-lg font-semibold text-foreground">Transaction Log</h3>
                                    <p className="text-sm text-muted-foreground">Detailed history for {periodLabel}</p>
                                </div>
                            </div>

                            <div className="overflow-x-auto">
                                <table className="w-full text-sm text-left">
                                    <thead className="text-xs text-muted-foreground uppercase bg-secondary/30">
                                        <tr>
                                            <th className="px-4 py-3 rounded-l-lg">Bill No.</th>
                                            <th className="px-4 py-3">Date</th>
                                            <th className="px-4 py-3">Time</th>
                                            <th className="px-4 py-3">Method</th>
                                            <th className="px-4 py-3">Amount</th>
                                            <th className="px-4 py-3 rounded-r-lg text-right">Status</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-border/30">
                                        {response?.payments && response.payments.length > 0 ? (
                                            response.payments.map((txn) => (
                                                <tr key={txn.id} className="hover:bg-accent/50 transition-colors">
                                                    <td className="px-4 py-3 font-medium text-foreground">{txn.bill_number}</td>
                                                    <td className="px-4 py-3 text-muted-foreground">
                                                        {new Date(txn.created_at).toLocaleDateString("en-IN", {
                                                            day: "2-digit",
                                                            month: "short",
                                                        })}
                                                    </td>
                                                    <td className="px-4 py-3 text-muted-foreground">
                                                        {new Date(txn.created_at).toLocaleTimeString("en-US", {
                                                            hour: "2-digit",
                                                            minute: "2-digit",
                                                        })}
                                                    </td>
                                                    <td className="px-4 py-3">
                                                        <span
                                                            className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                                                                txn.method === "Cash"
                                                                    ? "bg-amber-500/10 text-amber-500"
                                                                    : "bg-emerald-500/10 text-emerald-500"
                                                            }`}
                                                        >
                                                            {txn.method}
                                                        </span>
                                                    </td>
                                                    <td className="px-4 py-3 font-medium text-foreground">
                                                        ₹{Number(txn.amount).toLocaleString()}
                                                    </td>
                                                    <td className="px-4 py-3 text-right">
                                                        <span className="text-emerald-500 text-xs">Completed</span>
                                                    </td>
                                                </tr>
                                            ))
                                        ) : (
                                            <tr>
                                                <td colSpan={6} className="px-4 py-12 text-center text-muted-foreground">
                                                    No transactions found for {periodLabel.toLowerCase()}
                                                </td>
                                            </tr>
                                        )}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </>
                )}
            </div>
        </DashboardLayout>
    );
};

/** Skeleton shown while the first payments query is in flight. */
const PaymentsSkeleton = () => (
    <div className="space-y-6">
        <div className="grid gap-6 md:grid-cols-2">
            <div className="stat-card flex items-center justify-center min-h-[300px]">
                <div className="skeleton h-40 w-40 rounded-full" />
            </div>
            <div className="grid gap-4">
                <div className="stat-card">
                    <div className="skeleton h-4 w-32" />
                    <div className="skeleton mt-3 h-10 w-40" />
                </div>
                <div className="grid grid-cols-2 gap-4">
                    <div className="stat-card">
                        <div className="skeleton h-4 w-20" />
                        <div className="skeleton mt-3 h-7 w-24" />
                    </div>
                    <div className="stat-card">
                        <div className="skeleton h-4 w-20" />
                        <div className="skeleton mt-3 h-7 w-24" />
                    </div>
                </div>
            </div>
        </div>
        <div className="stat-card">
            <div className="skeleton h-5 w-40" />
            <div className="mt-6 space-y-3">
                {Array.from({ length: 6 }).map((_, i) => (
                    <div key={i} className="skeleton h-10 w-full" />
                ))}
            </div>
        </div>
    </div>
);

export default MachinePayments;
