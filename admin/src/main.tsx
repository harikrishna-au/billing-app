import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";

// Polyfill for Safari which doesn't support requestIdleCallback
if (typeof globalThis.requestIdleCallback === "undefined") {
  (globalThis as typeof globalThis & { requestIdleCallback: typeof requestIdleCallback }).requestIdleCallback = (
    cb: IdleRequestCallback,
    _options?: IdleRequestOptions
  ) => setTimeout(() => cb({ didTimeout: false, timeRemaining: () => 50 }), 1) as unknown as number;
  (globalThis as typeof globalThis & { cancelIdleCallback: typeof cancelIdleCallback }).cancelIdleCallback = (id: number) => clearTimeout(id);
}

createRoot(document.getElementById("root")!).render(<App />);
