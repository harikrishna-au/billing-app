import { useState } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Button } from "@/components/ui/button";
import { ArrowLeft, Calendar, CreditCard, DollarSign, Download, Filter, Loader2 } from "lucide-react";
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

const MachinePayments = () => {
    const navigate = useNavigate();
    const { id } = useParams();
    const [activeTab, setActiveTab] = useState<"day" | "week" | "month" | "date">("day");
    const [selectedDate, setSelectedDate] = useState<string>('');
    const [isExporting, setIsExporting] = useState(false);

    const handleExport = async () => {
        setIsExporting(true);
        try {
            const blob = await analyticsApi.exportData('payments', { machine_id: id });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `payments_${id}_${activeTab}.csv`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        } catch (e) {
            console.error('Export failed', e);
        } finally {
            setIsExporting(false);
        }
    };

    // Fetch machine data
    const { data: machine } = useQuery({
        queryKey: ['machine', id],
        queryFn: () => machinesApi.getById(id!),
        enabled: !!id,
    });

    // Fetch payment stats
    const { data: response, isLoading } = useQuery({
        queryKey: ['payments', id, activeTab, selectedDate],
        queryFn: () =>
            activeTab === 'date' && selectedDate
                ? paymentsApi.getByMachine(id!, { start_date: `${selectedDate}T00:00:00Z`, end_date: `${selectedDate}T23:59:59Z` })
                : paymentsApi.getByMachine(id!, { period: activeTab as 'day' | 'week' | 'month' }),
        enabled: !!id && (activeTab !== 'date' || !!selectedDate),
    });

    const summary = response?.summary;
    const onlineAmount = (summary?.upi_amount || 0) + (summary?.card_amount || 0);
    const offlineAmount = summary?.cash_amount || 0;

    const pieData = [
        { name: "Online (UPI/Card)", value: onlineAmount, color: "#10b981" }, // Green
        { name: "Offline (Cash)", value: offlineAmount, color: "#f59e0b" },   // Amber
    ];

    if (isLoading) {
        return (
            <DashboardLayout>
                <div className="flex items-center justify-center h-96">
                    <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
                </div>
            </DashboardLayout>
        );
    }

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
                                        <Link to="/clients">Hadoom Machines</Link>
                                    </BreadcrumbLink>
                                </BreadcrumbItem>
                                <BreadcrumbSeparator />
                                <BreadcrumbItem>
                                    <BreadcrumbLink asChild>
                                        <Link to={`/clients/${id}`}>{machine?.name || 'Unknown Machine'}</Link>
                                    </BreadcrumbLink>
                                </BreadcrumbItem>
                                <BreadcrumbSeparator />
                                <BreadcrumbItem>
                                    <BreadcrumbPage>Payments</BreadcrumbPage>
                                </BreadcrumbItem>
                            </BreadcrumbList>
                        </Breadcrumb>
                    </div>

                    <div className="flex items-center justify-between">
                        <div>
                            <h1 className="text-2xl font-bold text-foreground">Payments Analysis</h1>
                            <p className="text-muted-foreground">Machine ID: {id}</p>
                        </div>

                        <div className="flex items-center gap-2">
                            {/* Period tabs */}
                            <div className="flex items-center bg-secondary/50 p-1 rounded-lg border border-border/50">
                                {(["day", "week", "month"] as const).map((tab) => (
                                    <button
                                        key={tab}
                                        onClick={() => { setActiveTab(tab); setSelectedDate(''); }}
                                        className={`px-4 py-1.5 rounded-md text-sm font-medium transition-all ${activeTab === tab
                                            ? "bg-primary text-primary-foreground shadow-sm"
                                            : "text-muted-foreground hover:text-foreground"
                                            }`}
                                    >
                                        {tab.charAt(0).toUpperCase() + tab.slice(1)}
                                    </button>
                                ))}
                            </div>

                            {/* Date picker */}
                            <div className={`relative flex items-center gap-2 px-3 py-1.5 rounded-lg border text-sm font-medium transition-all cursor-pointer
                                ${activeTab === 'date'
                                    ? 'bg-primary text-primary-foreground border-primary'
                                    : 'bg-secondary/50 border-border/50 text-muted-foreground hover:text-foreground'}`}>
                                <Calendar className="h-4 w-4 shrink-0" />
                                <span className="whitespace-nowrap">
                                    {activeTab === 'date' && selectedDate
                                        ? new Date(selectedDate + 'T00:00:00').toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
                                        : 'Pick date'}
                                </span>
                                <input
                                    type="date"
                                    max={new Date().toISOString().split('T')[0]}
                                    value={selectedDate}
                                    onChange={(e) => { setSelectedDate(e.target.value); setActiveTab('date'); }}
                                    className="absolute opacity-0 w-0 h-0 pointer-events-none"
                                    tabIndex={-1}
                                />
                                <button
                                    onClick={(e) => {
                                        const input = e.currentTarget.previousElementSibling as HTMLInputElement;
                                        input?.showPicker?.();
                                    }}
                                    className="absolute inset-0 w-full h-full"
                                    aria-label="Pick date"
                                />
                            </div>
                        </div>
                    </div>
                </div>

                {/* Analytics Section */}
                <div className="grid gap-6 md:grid-cols-2 animate-slide-up">
                    {/* Pie Chart */}
                    <div className="stat-card flex flex-col items-center justify-center min-h-[300px]">
                        <h3 className="text-lg font-semibold text-foreground mb-4 w-full text-left">Collection Split</h3>
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
                                        contentStyle={{ backgroundColor: "hsl(224 14% 9%)", borderColor: "hsl(224 14% 16%)", color: "hsl(220 13% 93%)", borderRadius: "10px", fontFamily: "Outfit", fontSize: "13px" }}
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
                            <span className="text-sm text-muted-foreground">
                                Total Collections ({activeTab === 'date' && selectedDate
                                    ? new Date(selectedDate + 'T00:00:00').toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
                                    : activeTab})
                            </span>
                            <span className="text-4xl font-bold text-foreground mt-2">₹{summary?.total_amount.toLocaleString() || 0}</span>
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                            <div className="stat-card bg-emerald-500/10 border-emerald-500/20">
                                <div className="flex items-center gap-2 mb-2">
                                    <CreditCard className="h-4 w-4 text-emerald-500" />
                                    <span className="text-sm font-medium text-emerald-500">Online</span>
                                </div>
                                <span className="text-2xl font-bold text-foreground">₹{onlineAmount.toLocaleString()}</span>
                                <p className="text-xs text-muted-foreground mt-1">UPI, Credit/Debit Cards</p>
                            </div>
                            <div className="stat-card bg-amber-500/10 border-amber-500/20">
                                <div className="flex items-center gap-2 mb-2">
                                    <DollarSign className="h-4 w-4 text-amber-500" />
                                    <span className="text-sm font-medium text-amber-500">Offline</span>
                                </div>
                                <span className="text-2xl font-bold text-foreground">₹{offlineAmount.toLocaleString()}</span>
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
                            <p className="text-sm text-muted-foreground">
                                Detailed history for {activeTab === 'date' && selectedDate
                                    ? new Date(selectedDate + 'T00:00:00').toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
                                    : activeTab}
                            </p>
                        </div>
                        <Button variant="outline" size="sm" onClick={handleExport} disabled={isExporting}>
                            {isExporting
                                ? <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                                : <Download className="h-4 w-4 mr-2" />}
                            Export
                        </Button>
                    </div>

                    <div className="overflow-x-auto">
                        <table className="w-full text-sm text-left">
                            <thead className="text-xs text-muted-foreground uppercase bg-secondary/30">
                                <tr>
                                    <th className="px-4 py-3 rounded-l-lg">Bill No.</th>
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
                                                {new Date(txn.created_at).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}
                                            </td>
                                            <td className="px-4 py-3">
                                                <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium 
                                        ${txn.method === 'Cash'
                                                        ? 'bg-amber-500/10 text-amber-500'
                                                        : 'bg-emerald-500/10 text-emerald-500'}`}>
                                                    {txn.method}
                                                </span>
                                            </td>
                                            <td className="px-4 py-3 font-medium text-foreground">₹{Number(txn.amount).toLocaleString()}</td>
                                            <td className="px-4 py-3 text-right">
                                                <span className="text-emerald-500 text-xs">Completed</span>
                                            </td>
                                        </tr>
                                    ))
                                ) : (
                                    <tr>
                                        <td colSpan={5} className="px-4 py-8 text-center text-muted-foreground">
                                            No transactions found for this period
                                        </td>
                                    </tr>
                                )}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </DashboardLayout>
    );
};

export default MachinePayments;
