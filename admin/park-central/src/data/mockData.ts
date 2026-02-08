import { LogEntry } from "@/components/dashboard/ActivityLog";

export const clientsData: Record<string, {
    name: string;
    location: string;
    status: "online" | "offline" | "maintenance";
    lastSync: string;
    logs: LogEntry[];
    onlineCollection: number;
    offlineCollection: number; // Replaces activeSubscriptions logic
    catalog: { name: string; price: number; status: "active" | "inactive"; lastUpdated: string }[];
    catalogHistory: { id: string; action: string; details: string; timestamp: string; user: string }[];
    payments: { id: string; amount: number; date: string; status: "paid" | "pending" }[];
}> = {
    "1": {
        name: "Main Entrance POS",
        location: "Lobby A",
        status: "online",
        lastSync: "2 mins ago",
        onlineCollection: 12500,
        offlineCollection: 5000,
        logs: [
            { id: "l1", action: "Machine Online", details: "System startup sequence complete", timestamp: "Today, 09:00 AM", type: "system" },
            { id: "l2", action: "Machine Offline", details: "Shut down by operator", timestamp: "Yesterday, 10:30 PM", type: "system" },
        ],
        catalog: [
            { name: "Standard Parking", price: 50, status: "active", lastUpdated: "2 days ago" },
            { name: "Premium Valet", price: 150, status: "active", lastUpdated: "1 week ago" },
            { name: "Monthly Pass", price: 2500, status: "active", lastUpdated: "Today" },
        ],
        catalogHistory: [
            { id: "ch1", action: "Price Update", details: "Increased Monthly Pass from 2200 to 2500", timestamp: "Today, 10:00 AM", user: "Admin" },
            { id: "ch2", action: "Item Added", details: "Added Standard Parking service", timestamp: "2 days ago", user: "System" },
        ],
        payments: [
            { id: "TXN-001", amount: 1250, date: "Today, 10:00 AM", status: "paid" },
            { id: "TXN-002", amount: 500, date: "Today, 09:30 AM", status: "paid" },
        ],
    },
    "2": {
        name: "Cafeteria Kiosk",
        location: "Canteen",
        status: "online",
        lastSync: "5 mins ago",
        onlineCollection: 8500,
        offlineCollection: 2000,
        logs: [],
        catalog: [],
        catalogHistory: [],
        payments: [],
    },
    "3": {
        name: "Parking Gate 1",
        location: "Basement",
        status: "maintenance",
        lastSync: "1 hour ago",
        onlineCollection: 0,
        offlineCollection: 0,
        logs: [],
        catalog: [],
        catalogHistory: [],
        payments: [],
    },
    "4": {
        name: "Gift Shop",
        location: "First Floor",
        status: "offline",
        lastSync: "1 day ago",
        onlineCollection: 1200,
        offlineCollection: 3500,
        logs: [],
        catalog: [],
        catalogHistory: [],
        payments: [],
    },
};
