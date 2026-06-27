import { useNavigate } from "react-router-dom";
import { useEffect, useRef, useState, useCallback, ReactNode } from "react";

/* ─────────────────────────────────────────────────────────────────────────
   MIT BILLING — product landing page
   A billing & POS platform for counter businesses: ring up a sale, print a
   thermal bill, take Cash/Card/UPI, and watch every rupee land in the
   cloud dashboard in real time. Pure CSS + canvas, zero new deps.
   ───────────────────────────────────────────────────────────────────────── */

const FEATURES = [
  { idx: "01", icon: "🧾", name: "Thermal Bills, Instantly", blurb: "Tap to print crisp 2-inch invoices on any SmartPOS or Pine Labs device — GST lines, totals, the works.", c: "#7c6cff" },
  { idx: "02", icon: "💳", name: "Cash · Card · UPI",        blurb: "Accept every payment mode at the counter. Each sale is tagged, totalled, and reconciled automatically.", c: "#22d3ee" },
  { idx: "03", icon: "🖥️", name: "Many Machines, One View",   blurb: "Run dozens of counters across locations. Every terminal reports into a single live admin panel.", c: "#34d399" },
  { idx: "04", icon: "📡", name: "Offline-First Sync",        blurb: "Network drops? Sales keep happening. Bills queue locally and sync the instant you're back online.", c: "#fbbf24" },
  { idx: "05", icon: "📊", name: "Real-Time Analytics",       blurb: "Collections, payment split, busiest hours, machine uptime — all charted and ready to export.", c: "#f472b6" },
  { idx: "06", icon: "🗓️", name: "Day Summary Reports",       blurb: "One-tap end-of-day rollups: first-to-last bill, totals by mode, printed or exported in seconds.", c: "#60a5fa" },
];

const STATS = [
  { to: 250000, suffix: "+", label: "Bills Printed" },
  { to: 99,     suffix: "%", label: "Sync Uptime" },
  { to: 3,      suffix: "",  label: "Payment Modes" },
  { to: 60,     suffix: "s", label: "To First Sale" },
];

const STEPS = [
  { n: "1", t: "Ring it up", d: "Pick items from the catalog, confirm the order. The bill number locks the moment you collect." },
  { n: "2", t: "Print & pay", d: "A thermal invoice prints on the spot. Customer pays by Cash, Card, or UPI — tagged instantly." },
  { n: "3", t: "It's in the cloud", d: "The sale lands in your dashboard live — even after an offline stretch, nothing is ever lost." },
];

const WHY = [
  { icon: "🇮🇳", t: "Built for Indian Counters", d: "GST-compliant invoices, UPI-first checkout, and rupee formatting baked in — not bolted on.", span: 2 },
  { icon: "🔒", t: "Idempotent & Safe", d: "Duplicate-proof bill numbers, even on retries.", span: 1 },
  { icon: "⚡", t: "Walk-in Fast", d: "No queues, no lag — staff are billing in under a minute.", span: 1 },
  { icon: "🛰️", t: "Superadmin Control", d: "Manage admins, machines, locations and UPI approvals from one privileged console.", span: 2 },
];

export default function LandingPage() {
  const navigate = useNavigate();
  const goLogin = () => navigate("/login");

  useScrollReveal();
  const progress = useScrollProgress();

  return (
    <div className="mb-root">
      <FontsAndStyles />
      <GrainOverlay />

      <div className="mb-progress" style={{ transform: `scaleX(${progress})` }} />

      {/* ── NAV ── */}
      <nav className="mb-nav">
        <div className="mb-brand">
          <span className="mb-brand-mark">⟢</span>
          <span className="mb-brand-name">MIT&nbsp;Billing</span>
        </div>
        <Magnetic>
          <button className="mb-btn mb-btn-ghost" onClick={goLogin}>
            Admin Login <span className="mb-arrow">→</span>
          </button>
        </Magnetic>
      </nav>

      {/* ── HERO ── */}
      <header className="mb-hero">
        <NetworkCanvas />
        <div className="mb-hero-glow" />

        <div className="mb-hero-grid">
          {/* left: copy */}
          <div className="mb-hero-copy">
            <p className="mb-kicker reveal" data-reveal>
              <span className="mb-kicker-line" /> Billing &amp; POS Platform
            </p>

            <h1 className="mb-display">
              <span className="mb-line reveal" data-reveal style={{ ["--d" as string]: "0ms" }}>From sale to</span>
              <span className="mb-line reveal" data-reveal style={{ ["--d" as string]: "110ms" }}>
                <span className="mb-accent">receipt<span className="mb-dot">,</span></span>
              </span>
              <span className="mb-line reveal" data-reveal style={{ ["--d" as string]: "220ms" }}>in seconds.</span>
            </h1>

            <p className="mb-lede reveal" data-reveal style={{ ["--d" as string]: "330ms" }}>
              The all-in-one counter billing system — print thermal invoices,
              take Cash, Card &amp; UPI, manage every machine, and watch each
              sale sync to a live cloud dashboard.
            </p>

            <div className="mb-cta-row reveal" data-reveal style={{ ["--d" as string]: "440ms" }}>
              <Magnetic>
                <button
                  className="mb-btn mb-btn-primary"
                  onClick={() => document.getElementById("features")?.scrollIntoView({ behavior: "smooth" })}
                >
                  See How It Works
                </button>
              </Magnetic>
              <Magnetic>
                <button className="mb-btn mb-btn-line" onClick={goLogin}>
                  Open Dashboard
                </button>
              </Magnetic>
            </div>

            <div className="mb-trust reveal" data-reveal style={{ ["--d" as string]: "560ms" }}>
              <span>✓ GST-ready invoices</span>
              <span>✓ Works offline</span>
              <span>✓ SmartPOS &amp; Pine Labs</span>
            </div>
          </div>

          {/* right: live receipt mock */}
          <div className="mb-hero-visual reveal" data-reveal style={{ ["--d" as string]: "300ms" }}>
            <ReceiptMock />
          </div>
        </div>

        <div className="mb-scroll-hint reveal" data-reveal style={{ ["--d" as string]: "700ms" }}>
          <span>SCROLL</span>
          <span className="mb-scroll-bar"><i /></span>
        </div>
      </header>

      {/* ── MARQUEE ── */}
      <div className="mb-marquee">
        <div className="mb-marquee-track">
          {Array.from({ length: 2 }).map((_, k) => (
            <span key={k} className="mb-marquee-group" aria-hidden={k === 1}>
              {["Thermal Printing", "UPI Checkout", "GST Invoices", "Offline Sync", "Multi-Machine", "Day Summary", "Live Analytics"].map((w) => (
                <span key={w} className="mb-marquee-item">
                  {w} <span className="mb-marquee-star">✦</span>
                </span>
              ))}
            </span>
          ))}
        </div>
      </div>

      {/* ── STATS ── */}
      <section className="mb-stats">
        {STATS.map((s) => (
          <div key={s.label} className="mb-stat reveal" data-reveal>
            <CountUp to={s.to} suffix={s.suffix} />
            <span className="mb-stat-label">{s.label}</span>
          </div>
        ))}
      </section>

      {/* ── FEATURES ── */}
      <section id="features" className="mb-section">
        <div className="mb-section-head">
          <p className="mb-eyebrow reveal" data-reveal>Capabilities</p>
          <h2 className="mb-h2 reveal" data-reveal style={{ ["--d" as string]: "80ms" }}>
            Everything a counter <em>needs.</em>
          </h2>
        </div>

        <div className="mb-grid">
          {FEATURES.map((f, i) => (
            <article
              key={f.name}
              className="mb-card reveal"
              data-reveal
              style={{ ["--d" as string]: `${i * 70}ms`, ["--c" as string]: f.c }}
            >
              <div className="mb-card-top">
                <span className="mb-card-idx">{f.idx}</span>
                <span className="mb-card-icon">{f.icon}</span>
              </div>
              <h3 className="mb-card-name">{f.name}</h3>
              <p className="mb-card-blurb">{f.blurb}</p>
              <div className="mb-card-sheen" />
            </article>
          ))}
        </div>
      </section>

      {/* ── HOW IT WORKS ── */}
      <section className="mb-section mb-how">
        <div className="mb-section-head">
          <p className="mb-eyebrow reveal" data-reveal>The Flow</p>
          <h2 className="mb-h2 reveal" data-reveal style={{ ["--d" as string]: "80ms" }}>
            Three taps to <em>done.</em>
          </h2>
        </div>

        <div className="mb-steps">
          <div className="mb-steps-line" />
          {STEPS.map((s, i) => (
            <div key={s.n} className="mb-step reveal" data-reveal style={{ ["--d" as string]: `${i * 90}ms` }}>
              <div className="mb-step-num">{s.n}</div>
              <h3 className="mb-step-title">{s.t}</h3>
              <p className="mb-step-desc">{s.d}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── WHY (bento) ── */}
      <section className="mb-section">
        <div className="mb-section-head">
          <p className="mb-eyebrow reveal" data-reveal>Why MIT</p>
          <h2 className="mb-h2 reveal" data-reveal style={{ ["--d" as string]: "80ms" }}>
            Made to be <em>trusted.</em>
          </h2>
        </div>

        <div className="mb-bento">
          {WHY.map((w, i) => (
            <div
              key={w.t}
              className={`mb-bento-cell reveal span-${w.span}`}
              data-reveal
              style={{ ["--d" as string]: `${i * 70}ms` }}
            >
              <span className="mb-bento-icon">{w.icon}</span>
              <h3 className="mb-bento-title">{w.t}</h3>
              <p className="mb-bento-desc">{w.d}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── PRICING ── */}
      <section className="mb-section">
        <div className="mb-section-head">
          <p className="mb-eyebrow reveal" data-reveal>Pricing</p>
          <h2 className="mb-h2 reveal" data-reveal style={{ ["--d" as string]: "80ms" }}>
            Plans for every <em>scale.</em>
          </h2>
        </div>

        <div className="mb-pricing-grid">
          {/* Single Device Plan */}
          <div className="mb-pricing-card mb-pricing-starter reveal" data-reveal style={{ ["--d" as string]: "100ms" }}>
            <div className="mb-pricing-tier">Single Device</div>
            <div className="mb-pricing-desc">Perfect for small shops and single counters</div>

            <div className="mb-pricing-breakdown">
              <div className="mb-pricing-row">
                <span className="mb-pricing-label">Monthly subscription</span>
                <span className="mb-pricing-amount">₹5,000<i>/mo</i></span>
              </div>
              <div className="mb-pricing-row mb-pricing-row-secondary">
                <span className="mb-pricing-label">POS Hardware</span>
                <span className="mb-pricing-amount">₹12,000<i>one-time</i></span>
              </div>
            </div>

            <ul className="mb-pricing-features">
              <li><span className="mb-check">✓</span> 1 Thermal Printer</li>
              <li><span className="mb-check">✓</span> Cash, Card & UPI</li>
              <li><span className="mb-check">✓</span> Daily Reports</li>
              <li><span className="mb-check">✓</span> Offline Sync</li>
              <li><span className="mb-check">✓</span> Cloud Dashboard</li>
            </ul>

            <Magnetic>
              <button className="mb-btn mb-btn-primary mb-pricing-btn" onClick={goLogin}>
                Get Started
              </button>
            </Magnetic>
          </div>

          {/* Enterprise Plan */}
          <div className="mb-pricing-card mb-pricing-enterprise reveal" data-reveal style={{ ["--d" as string]: "200ms" }}>
            <div className="mb-pricing-badge">Recommended</div>
            <div className="mb-pricing-tier">Enterprise</div>
            <div className="mb-pricing-desc">Multi-location chains and high-volume merchants</div>

            <div className="mb-pricing-breakdown">
              <div className="mb-pricing-row">
                <span className="mb-pricing-label">Custom pricing</span>
                <span className="mb-pricing-amount">Based on volume</span>
              </div>
              <div className="mb-pricing-row mb-pricing-row-secondary">
                <span className="mb-pricing-label">Hardware & Setup</span>
                <span className="mb-pricing-amount">Custom quote</span>
              </div>
            </div>

            <ul className="mb-pricing-features">
              <li><span className="mb-check">✓</span> Unlimited Machines</li>
              <li><span className="mb-check">✓</span> Multi-Location</li>
              <li><span className="mb-check">✓</span> Superadmin Console</li>
              <li><span className="mb-check">✓</span> Priority Support</li>
              <li><span className="mb-check">✓</span> Custom Integration</li>
            </ul>

            <Magnetic>
              <button className="mb-btn mb-btn-line mb-pricing-btn" onClick={goLogin}>
                Contact Us
              </button>
            </Magnetic>
          </div>
        </div>
      </section>

      {/* ── FINAL CTA ── */}
      <section className="mb-final">
        <div className="mb-final-card reveal" data-reveal>
          <div className="mb-final-glow" />
          <p className="mb-eyebrow" style={{ position: "relative" }}>Ready to bill smarter?</p>
          <h2 className="mb-final-title">
            Your counter,<br /><em>upgraded.</em>
          </h2>
          <p className="mb-final-sub">
            Sign in to manage machines, track every payment, and print your next bill.
          </p>
          <Magnetic>
            <button className="mb-btn mb-btn-primary mb-btn-lg" onClick={goLogin}>
              Open the Dashboard <span className="mb-arrow">→</span>
            </button>
          </Magnetic>
        </div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="mb-footer">
        <div className="mb-brand">
          <span className="mb-brand-mark">⟢</span>
          <span className="mb-brand-name">MIT&nbsp;Billing</span>
        </div>
        <span className="mb-footer-note">© {new Date().getFullYear()} · Billing &amp; POS platform · GST-compliant</span>
      </footer>
    </div>
  );
}

/* ───────────────────────── Live thermal receipt mock ─────────────────── */
function ReceiptMock() {
  return (
    <div className="mb-receipt-wrap">
      <div className="mb-receipt">
        <div className="mb-rcpt-title">INVOICE</div>
        <div className="mb-rcpt-dash" />
        <div className="mb-rcpt-row"><span>GSTIN</span><span>27AABCO1234H1Z0</span></div>
        <div className="mb-rcpt-row"><span>Bill No</span><span>B/2024/00142</span></div>
        <div className="mb-rcpt-row"><span>Date</span><span>27-06-26 17:30:24</span></div>
        <div className="mb-rcpt-dash" />
        <div className="mb-rcpt-cols mb-rcpt-head"><span>QTY ITEM</span><span>PRICE</span></div>
        <div className="mb-rcpt-cols"><span>2x Service</span><span>1500.00</span></div>
        <div className="mb-rcpt-cols"><span>1x Product</span><span>1200.00</span></div>
        <div className="mb-rcpt-dash" />
        <div className="mb-rcpt-cols"><span>Subtotal</span><span>2288.14</span></div>
        <div className="mb-rcpt-cols mb-rcpt-mute"><span>CGST 9%</span><span>205.93</span></div>
        <div className="mb-rcpt-cols mb-rcpt-mute"><span>SGST 9%</span><span>205.93</span></div>
        <div className="mb-rcpt-total"><span>TOTAL</span><span>₹2700.00</span></div>
        <div className="mb-rcpt-pay"><span>Pay</span><span>UPI</span></div>
        <div className="mb-rcpt-dash" />
        <div className="mb-rcpt-thanks">Thank you! Visit again</div>
        <div className="mb-receipt-perf" />
      </div>
      <div className="mb-paid-chip">
        <span className="mb-paid-check">✓</span> PAID
      </div>
    </div>
  );
}

/* ───────────────────────── Magnetic button wrapper ───────────────────── */
function Magnetic({ children }: { children: ReactNode }) {
  const ref = useRef<HTMLSpanElement>(null);
  const onMove = (e: React.MouseEvent) => {
    const el = ref.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    const x = e.clientX - (r.left + r.width / 2);
    const y = e.clientY - (r.top + r.height / 2);
    el.style.transform = `translate(${x * 0.25}px, ${y * 0.35}px)`;
  };
  const reset = () => { if (ref.current) ref.current.style.transform = "translate(0,0)"; };
  return (
    <span ref={ref} className="mb-magnetic" onMouseMove={onMove} onMouseLeave={reset}>
      {children}
    </span>
  );
}

/* ───────────────────────── Count-up on reveal ────────────────────────── */
function CountUp({ to, suffix }: { to: number; suffix: string }) {
  const ref = useRef<HTMLSpanElement>(null);
  const [val, setVal] = useState(0);
  const done = useRef(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((en) => {
          if (en.isIntersecting && !done.current) {
            done.current = true;
            const dur = 1700;
            const start = performance.now();
            const tick = (now: number) => {
              const p = Math.min((now - start) / dur, 1);
              const eased = 1 - Math.pow(1 - p, 3);
              setVal(Math.round(to * eased));
              if (p < 1) requestAnimationFrame(tick);
            };
            requestAnimationFrame(tick);
          }
        });
      },
      { threshold: 0.5 }
    );
    io.observe(el);
    return () => io.disconnect();
  }, [to]);

  const fmt = val >= 1000 ? val.toLocaleString("en-IN") : String(val);
  return (
    <span ref={ref} className="mb-stat-num">
      {fmt}<span className="mb-stat-suffix">{suffix}</span>
    </span>
  );
}

/* ───────────────────────── Scroll reveal (shared IO) ─────────────────── */
function useScrollReveal() {
  useEffect(() => {
    const els = Array.from(document.querySelectorAll<HTMLElement>("[data-reveal]"));
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            e.target.classList.add("is-visible");
            io.unobserve(e.target);
          }
        });
      },
      { threshold: 0.15, rootMargin: "0px 0px -8% 0px" }
    );
    els.forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);
}

/* ───────────────────────── Scroll progress bar ───────────────────────── */
function useScrollProgress() {
  const [p, setP] = useState(0);
  useEffect(() => {
    const onScroll = () => {
      const h = document.documentElement.scrollHeight - window.innerHeight;
      setP(h > 0 ? Math.min(window.scrollY / h, 1) : 0);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);
  return p;
}

/* ───────────────────────── Network constellation canvas ──────────────── */
/* Nodes = POS machines; lines = sync links to the cloud. */
function NetworkCanvas() {
  const ref = useRef<HTMLCanvasElement>(null);

  const setup = useCallback(() => {
    const canvas = ref.current;
    if (!canvas) return () => {};
    const ctx = canvas.getContext("2d");
    if (!ctx) return () => {};

    let raf = 0, W = 0, H = 0;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    type N = { x: number; y: number; vx: number; vy: number; r: number };
    let nodes: N[] = [];

    const resize = () => {
      W = window.innerWidth; H = window.innerHeight;
      canvas.width = W * dpr; canvas.height = H * dpr;
      canvas.style.width = W + "px"; canvas.style.height = H + "px";
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      const count = Math.min(64, Math.round((W * H) / 26000));
      nodes = Array.from({ length: count }, () => ({
        x: Math.random() * W, y: Math.random() * H,
        vx: (Math.random() - 0.5) * 0.25, vy: (Math.random() - 0.5) * 0.25,
        r: Math.random() * 1.8 + 0.8,
      }));
    };
    resize();
    window.addEventListener("resize", resize);

    const LINK = 130;
    const draw = () => {
      ctx.clearRect(0, 0, W, H);

      for (const n of nodes) {
        n.x += n.vx; n.y += n.vy;
        if (n.x < 0 || n.x > W) n.vx *= -1;
        if (n.y < 0 || n.y > H) n.vy *= -1;
      }
      // links
      for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < nodes.length; j++) {
          const a = nodes[i], b = nodes[j];
          const dx = a.x - b.x, dy = a.y - b.y;
          const d = Math.hypot(dx, dy);
          if (d < LINK) {
            const o = (1 - d / LINK) * 0.18;
            ctx.strokeStyle = `rgba(124,108,255,${o})`;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
          }
        }
      }
      // nodes
      for (const n of nodes) {
        ctx.beginPath();
        ctx.arc(n.x, n.y, n.r, 0, Math.PI * 2);
        ctx.fillStyle = "rgba(150,200,255,.5)";
        ctx.fill();
      }
      raf = requestAnimationFrame(draw);
    };
    draw();

    return () => { cancelAnimationFrame(raf); window.removeEventListener("resize", resize); };
  }, []);

  useEffect(() => setup(), [setup]);
  return <canvas ref={ref} className="mb-canvas" aria-hidden />;
}

/* ───────────────────────── Grain overlay (SVG) ───────────────────────── */
function GrainOverlay() {
  return (
    <svg className="mb-grain" aria-hidden>
      <filter id="mb-noise">
        <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" stitchTiles="stitch" />
        <feColorMatrix type="saturate" values="0" />
      </filter>
      <rect width="100%" height="100%" filter="url(#mb-noise)" />
    </svg>
  );
}

/* ───────────────────────── Fonts + all CSS ───────────────────────────── */
function FontsAndStyles() {
  return (
    <>
      <link rel="preconnect" href="https://fonts.googleapis.com" />
      <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      <link
        href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,400;12..96,600;12..96,700;12..96,800&family=Instrument+Serif:ital@0;1&family=DM+Sans:opsz,wght@9..40,300;9..40,400;9..40,500&family=JetBrains+Mono:wght@400;500;700&display=swap"
        rel="stylesheet"
      />
      <style>{CSS}</style>
    </>
  );
}

const CSS = `
.mb-root{
  --bg:#070912; --ink:#eef1ff; --indigo:#7c6cff; --cyan:#22d3ee; --mint:#34d399;
  --muted:rgba(238,241,255,.55); --faint:rgba(238,241,255,.34);
  --line:rgba(140,150,220,.14);
  font-family:'DM Sans',sans-serif; color:var(--ink);
  background:
    radial-gradient(120% 80% at 50% -10%, rgba(124,108,255,.16) 0%, transparent 55%),
    radial-gradient(80% 50% at 90% 20%, rgba(34,211,238,.08) 0%, transparent 60%),
    linear-gradient(180deg,#0b0e1c 0%,#090b16 30%,#070912 70%,#05060d 100%);
  overflow-x:hidden; position:relative;
}
.mb-root *{box-sizing:border-box;}

.mb-grain{position:fixed;inset:0;width:100%;height:100%;opacity:.045;pointer-events:none;z-index:9;mix-blend-mode:overlay;}
.mb-progress{position:fixed;top:0;left:0;height:3px;width:100%;z-index:120;
  background:linear-gradient(90deg,var(--indigo),var(--cyan));transform-origin:0 50%;transform:scaleX(0);
  box-shadow:0 0 18px rgba(124,108,255,.6);}

/* nav */
.mb-nav{position:fixed;top:0;left:0;right:0;z-index:100;display:flex;align-items:center;
  justify-content:space-between;padding:18px clamp(20px,5vw,56px);
  background:linear-gradient(180deg,rgba(7,9,18,.72),transparent);
  backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);}
.mb-brand{display:flex;align-items:center;gap:11px;}
.mb-brand-mark{font-size:20px;color:var(--indigo);line-height:1;text-shadow:0 0 18px rgba(124,108,255,.7);}
.mb-brand-name{font-weight:700;font-size:15px;letter-spacing:1px;}

/* buttons */
.mb-magnetic{display:inline-block;transition:transform .25s cubic-bezier(.2,.8,.2,1);will-change:transform;}
.mb-btn{font-family:'DM Sans',sans-serif;font-weight:600;cursor:pointer;border:none;border-radius:999px;
  display:inline-flex;align-items:center;gap:8px;font-size:14px;
  transition:transform .2s,box-shadow .3s,background .3s,color .3s,border-color .3s;}
.mb-arrow{transition:transform .25s;}
.mb-btn:hover .mb-arrow{transform:translateX(4px);}
.mb-btn-ghost{padding:10px 20px;background:rgba(255,255,255,.05);color:var(--ink);
  border:1px solid var(--line);backdrop-filter:blur(8px);}
.mb-btn-ghost:hover{background:rgba(124,108,255,.14);border-color:rgba(124,108,255,.5);}
.mb-btn-primary{padding:15px 32px;color:#fff;
  background:linear-gradient(135deg,var(--indigo),#5b8cff 60%,var(--cyan));
  font-weight:700;box-shadow:0 8px 40px rgba(124,108,255,.32),inset 0 1px 0 rgba(255,255,255,.35);}
.mb-btn-primary:hover{box-shadow:0 12px 60px rgba(124,108,255,.55),inset 0 1px 0 rgba(255,255,255,.5);}
.mb-btn-lg{padding:17px 40px;font-size:15px;}
.mb-btn-line{padding:15px 30px;background:transparent;color:var(--ink);border:1.5px solid rgba(140,150,220,.35);}
.mb-btn-line:hover{border-color:var(--indigo);color:#cdc8ff;background:rgba(124,108,255,.07);}

/* hero */
.mb-hero{position:relative;min-height:100svh;display:flex;flex-direction:column;justify-content:center;
  padding:130px clamp(20px,5vw,64px) 70px;overflow:hidden;}
.mb-canvas{position:absolute;inset:0;z-index:0;pointer-events:none;opacity:.7;}
.mb-hero-glow{position:absolute;top:8%;left:55%;width:min(800px,80vw);height:560px;z-index:0;pointer-events:none;
  background:radial-gradient(ellipse at center,rgba(124,108,255,.20),transparent 65%);filter:blur(20px);}
.mb-hero-grid{position:relative;z-index:2;max-width:1180px;margin:0 auto;width:100%;
  display:grid;grid-template-columns:1.05fr .95fr;gap:clamp(30px,5vw,64px);align-items:center;}

.mb-kicker{display:inline-flex;align-items:center;gap:12px;font-size:12.5px;letter-spacing:3px;
  text-transform:uppercase;color:var(--cyan);margin:0 0 24px;font-weight:500;}
.mb-kicker-line{width:34px;height:1px;background:linear-gradient(90deg,transparent,var(--cyan));}

.mb-display{font-family:'Bricolage Grotesque',sans-serif;font-weight:800;
  font-size:clamp(46px,6.6vw,86px);line-height:.95;letter-spacing:-.04em;margin:0 0 26px;
  display:flex;flex-direction:column;}
.mb-line{display:block;}
.mb-accent{font-family:'Instrument Serif',serif;font-style:italic;font-weight:400;letter-spacing:-.01em;
  background:linear-gradient(135deg,var(--indigo) 0%,#5b8cff 50%,var(--cyan) 110%);
  -webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent;}
.mb-dot{color:var(--cyan);-webkit-text-fill-color:var(--cyan);}

.mb-lede{font-size:clamp(15px,1.6vw,18px);line-height:1.65;color:var(--muted);font-weight:300;
  max-width:500px;margin:0 0 34px;}
.mb-cta-row{display:flex;gap:14px;flex-wrap:wrap;}
.mb-trust{display:flex;gap:20px;flex-wrap:wrap;margin-top:30px;font-size:13px;color:var(--faint);font-weight:400;}
.mb-trust span{white-space:nowrap;}

/* receipt mock */
.mb-hero-visual{display:flex;justify-content:center;perspective:1200px;}
.mb-receipt-wrap{position:relative;animation:mbFloat 6s ease-in-out infinite;}
@keyframes mbFloat{0%,100%{transform:translateY(0) rotateX(6deg) rotateY(-9deg)}50%{transform:translateY(-14px) rotateX(6deg) rotateY(-9deg)}}
.mb-receipt{width:280px;background:#fdfdf8;color:#15161a;border-radius:6px;
  padding:22px 22px 30px;font-family:'JetBrains Mono',monospace;font-size:11.5px;line-height:1.5;
  box-shadow:0 40px 80px -24px rgba(0,0,0,.7),0 0 0 1px rgba(255,255,255,.04);
  position:relative;clip-path:inset(0 0 0 0);
  animation:mbPrint 1.1s cubic-bezier(.2,.8,.2,1) .3s both;}
@keyframes mbPrint{from{clip-path:inset(0 0 100% 0)}to{clip-path:inset(0 0 0 0)}}
.mb-rcpt-org{text-align:center;font-weight:700;font-size:13px;letter-spacing:.3px;}
.mb-rcpt-title{text-align:center;font-weight:700;font-size:15px;letter-spacing:3px;margin:2px 0 6px;}
.mb-rcpt-dash{border-top:1.5px dashed #b9b9ad;margin:7px 0;}
.mb-rcpt-row{display:flex;justify-content:space-between;gap:8px;}
.mb-rcpt-row span:last-child{color:#3a3a40;}
.mb-rcpt-cols{display:flex;justify-content:space-between;gap:8px;}
.mb-rcpt-head{font-weight:700;}
.mb-rcpt-mute{color:#6a6a70;}
.mb-rcpt-total{display:flex;justify-content:space-between;font-weight:700;font-size:15px;margin-top:6px;}
.mb-rcpt-pay{display:flex;justify-content:space-between;font-weight:500;margin-top:2px;}
.mb-rcpt-thanks{text-align:center;margin-top:4px;font-size:11px;}
.mb-receipt-perf{position:absolute;left:0;right:0;bottom:-6px;height:12px;
  background:radial-gradient(circle at 6px -2px,transparent 0 5px,#fdfdf8 5px) repeat-x;
  background-size:12px 12px;}
.mb-paid-chip{position:absolute;top:-14px;right:-18px;display:inline-flex;align-items:center;gap:6px;
  padding:9px 16px;border-radius:999px;font-family:'DM Sans',sans-serif;font-weight:800;font-size:13px;
  letter-spacing:1px;color:#04210f;background:linear-gradient(135deg,var(--mint),#10b981);
  box-shadow:0 10px 30px rgba(52,211,153,.4);transform:rotate(7deg);
  animation:mbStamp .5s cubic-bezier(.2,1.4,.4,1) 1.3s both;}
@keyframes mbStamp{from{opacity:0;transform:rotate(7deg) scale(1.8)}to{opacity:1;transform:rotate(7deg) scale(1)}}
.mb-paid-check{display:inline-flex;width:17px;height:17px;align-items:center;justify-content:center;
  background:#04210f;color:var(--mint);border-radius:50%;font-size:11px;}

/* scroll hint */
.mb-scroll-hint{position:absolute;bottom:26px;left:50%;transform:translateX(-50%);z-index:2;
  display:flex;flex-direction:column;align-items:center;gap:9px;font-size:10px;letter-spacing:3px;color:var(--faint);}
.mb-scroll-bar{width:1.5px;height:40px;background:linear-gradient(180deg,var(--indigo),transparent);
  position:relative;overflow:hidden;border-radius:2px;}
.mb-scroll-bar i{position:absolute;top:0;left:0;width:100%;height:40%;background:var(--indigo);border-radius:2px;
  animation:mbScroll 1.8s ease-in-out infinite;box-shadow:0 0 8px var(--indigo);}
@keyframes mbScroll{0%{transform:translateY(-100%)}60%,100%{transform:translateY(260%)}}

/* marquee */
.mb-marquee{position:relative;z-index:3;border-top:1px solid var(--line);border-bottom:1px solid var(--line);
  padding:20px 0;overflow:hidden;background:rgba(9,11,22,.5);
  -webkit-mask-image:linear-gradient(90deg,transparent,#000 8%,#000 92%,transparent);
  mask-image:linear-gradient(90deg,transparent,#000 8%,#000 92%,transparent);}
.mb-marquee-track{display:flex;width:max-content;animation:mbMarquee 28s linear infinite;}
.mb-marquee-group{display:flex;}
.mb-marquee-item{font-family:'Bricolage Grotesque',sans-serif;font-weight:700;
  font-size:clamp(18px,3vw,32px);letter-spacing:-.02em;color:rgba(238,241,255,.15);
  padding:0 26px;display:inline-flex;align-items:center;gap:26px;white-space:nowrap;text-transform:uppercase;}
.mb-marquee-star{color:var(--indigo);font-size:.5em;}
@keyframes mbMarquee{to{transform:translateX(-50%)}}

/* stats */
.mb-stats{display:grid;grid-template-columns:repeat(4,1fr);max-width:1000px;margin:0 auto;
  padding:clamp(60px,8vw,104px) clamp(20px,5vw,40px);gap:24px;}
.mb-stat{text-align:center;border-left:1px solid var(--line);padding:6px 0 6px 24px;}
.mb-stat:first-child{border-left:none;padding-left:0;}
.mb-stat-num{font-family:'Bricolage Grotesque',sans-serif;font-weight:800;
  font-size:clamp(32px,4.6vw,54px);letter-spacing:-.03em;line-height:1;
  background:linear-gradient(135deg,#fff,var(--cyan));-webkit-background-clip:text;background-clip:text;
  -webkit-text-fill-color:transparent;display:inline-flex;align-items:baseline;}
.mb-stat-suffix{font-size:.5em;margin-left:2px;-webkit-text-fill-color:var(--cyan);}
.mb-stat-label{display:block;margin-top:10px;font-size:12.5px;letter-spacing:1px;color:var(--faint);text-transform:uppercase;}

/* sections */
.mb-section{max-width:1160px;margin:0 auto;padding:clamp(40px,7vw,90px) clamp(20px,5vw,40px);}
.mb-section-head{margin-bottom:clamp(38px,6vw,64px);}
.mb-eyebrow{font-size:12px;letter-spacing:3px;text-transform:uppercase;color:var(--cyan);margin:0 0 14px;font-weight:600;}
.mb-h2{font-family:'Bricolage Grotesque',sans-serif;font-weight:800;
  font-size:clamp(36px,6vw,72px);line-height:.96;letter-spacing:-.035em;margin:0;max-width:16ch;}
.mb-h2 em{font-family:'Instrument Serif',serif;font-style:italic;font-weight:400;color:var(--cyan);}

/* feature grid */
.mb-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:18px;}
.mb-card{position:relative;padding:30px 28px;border-radius:22px;overflow:hidden;border:1px solid var(--line);
  background:linear-gradient(180deg,rgba(255,255,255,.035),rgba(255,255,255,.01));
  transition:transform .35s cubic-bezier(.2,.8,.2,1),border-color .35s,box-shadow .35s;}
.mb-card:hover{transform:translateY(-6px);border-color:color-mix(in srgb,var(--c) 50%,transparent);
  box-shadow:0 24px 60px -20px color-mix(in srgb,var(--c) 42%,transparent);}
.mb-card-top{display:flex;align-items:center;justify-content:space-between;margin-bottom:22px;}
.mb-card-idx{font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:13px;letter-spacing:1px;color:var(--c);}
.mb-card-icon{font-size:30px;filter:drop-shadow(0 6px 14px rgba(0,0,0,.4));transition:transform .35s;}
.mb-card:hover .mb-card-icon{transform:scale(1.16) rotate(-6deg);}
.mb-card-name{font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:22px;letter-spacing:-.02em;margin:0 0 11px;}
.mb-card-blurb{font-size:14px;line-height:1.65;color:var(--muted);font-weight:300;margin:0;}
.mb-card-sheen{position:absolute;top:-60%;left:-30%;width:60%;height:220%;
  background:linear-gradient(90deg,transparent,rgba(255,255,255,.06),transparent);
  transform:rotate(18deg) translateX(-120%);transition:transform .7s;pointer-events:none;}
.mb-card:hover .mb-card-sheen{transform:rotate(18deg) translateX(360%);}

/* how it works */
.mb-steps{position:relative;display:grid;grid-template-columns:repeat(3,1fr);gap:24px;}
.mb-steps-line{position:absolute;top:26px;left:8%;right:8%;height:1px;
  background:linear-gradient(90deg,transparent,var(--line),var(--line),transparent);}
.mb-step{position:relative;}
.mb-step-num{width:52px;height:52px;border-radius:50%;display:flex;align-items:center;justify-content:center;
  font-family:'Bricolage Grotesque',sans-serif;font-weight:800;font-size:20px;color:#fff;margin-bottom:20px;
  background:linear-gradient(135deg,var(--indigo),var(--cyan));
  box-shadow:0 10px 30px rgba(124,108,255,.4);position:relative;z-index:1;}
.mb-step-title{font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:20px;letter-spacing:-.02em;margin:0 0 9px;}
.mb-step-desc{font-size:14px;line-height:1.65;color:var(--muted);font-weight:300;margin:0;max-width:34ch;}

/* bento */
.mb-bento{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;}
.mb-bento-cell{position:relative;padding:34px 30px;border-radius:22px;overflow:hidden;border:1px solid var(--line);
  background:linear-gradient(160deg,rgba(124,108,255,.06),rgba(255,255,255,.01));transition:transform .35s,border-color .35s;}
.mb-bento-cell:hover{transform:translateY(-4px);border-color:rgba(124,108,255,.36);}
.mb-bento-cell.span-2{grid-column:span 2;}
.mb-bento-icon{font-size:30px;display:block;margin-bottom:16px;}
.mb-bento-title{font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:20px;letter-spacing:-.02em;margin:0 0 9px;}
.mb-bento-desc{font-size:14px;line-height:1.6;color:var(--muted);font-weight:300;margin:0;max-width:48ch;}

/* pricing */
.mb-pricing-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:28px;}
.mb-pricing-card{position:relative;padding:40px 36px;border-radius:24px;border:1.5px solid var(--line);
  background:linear-gradient(160deg,rgba(255,255,255,.04),rgba(255,255,255,.01));
  transition:transform .35s,border-color .35s,box-shadow .35s;display:flex;flex-direction:column;}
.mb-pricing-card:hover{transform:translateY(-6px);border-color:rgba(124,108,255,.36);
  box-shadow:0 24px 60px -20px rgba(124,108,255,.32);}
.mb-pricing-enterprise{border-color:rgba(124,108,255,.5);background:linear-gradient(160deg,rgba(124,108,255,.12),rgba(255,255,255,.02));}
.mb-pricing-enterprise:hover{border-color:rgba(124,108,255,.8);}
.mb-pricing-badge{position:absolute;top:-14px;right:24px;display:inline-block;padding:6px 16px;border-radius:999px;
  font-family:'Bricolage Grotesque',sans-serif;font-weight:700;font-size:11px;letter-spacing:1.5px;
  text-transform:uppercase;color:#022;background:linear-gradient(135deg,var(--indigo),#5b8cff);
  box-shadow:0 8px 24px rgba(124,108,255,.3);}
.mb-pricing-tier{font-family:'Bricolage Grotesque',sans-serif;font-weight:800;font-size:26px;
  letter-spacing:-.02em;margin:0 0 8px;color:#fff;}
.mb-pricing-desc{font-size:14px;color:var(--muted);margin:0 0 28px;line-height:1.5;}
.mb-pricing-breakdown{margin-bottom:32px;padding-bottom:28px;border-bottom:1px solid var(--line);}
.mb-pricing-row{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;}
.mb-pricing-row:last-child{margin-bottom:0;}
.mb-pricing-row-secondary .mb-pricing-label{color:var(--faint);}
.mb-pricing-label{font-size:14px;color:var(--muted);}
.mb-pricing-amount{font-family:'Bricolage Grotesque',sans-serif;font-weight:800;font-size:20px;
  letter-spacing:-.02em;color:var(--cyan);}
.mb-pricing-amount i{font-style:normal;font-size:12px;font-weight:400;color:var(--faint);margin-left:4px;}
.mb-pricing-features{list-style:none;padding:0;margin:0 0 32px;display:flex;flex-direction:column;gap:12px;flex-grow:1;}
.mb-pricing-features li{display:flex;align-items:center;gap:10px;font-size:14px;color:var(--muted);}
.mb-check{display:inline-flex;width:18px;height:18px;align-items:center;justify-content:center;
  border-radius:4px;background:rgba(52,211,153,.15);color:var(--mint);font-size:11px;font-weight:700;}
.mb-pricing-btn{width:100%;}

/* final CTA */
.mb-final{padding:clamp(56px,9vw,120px) clamp(20px,5vw,40px);}
.mb-final-card{position:relative;max-width:760px;margin:0 auto;text-align:center;overflow:hidden;
  padding:clamp(48px,7vw,84px) clamp(28px,5vw,56px);border-radius:32px;border:1px solid rgba(124,108,255,.24);
  background:linear-gradient(160deg,rgba(124,108,255,.12),rgba(34,211,238,.05) 60%,transparent);}
.mb-final-glow{position:absolute;top:-40%;left:50%;transform:translateX(-50%);width:460px;height:460px;border-radius:50%;
  pointer-events:none;background:radial-gradient(circle,rgba(124,108,255,.2),transparent 65%);}
.mb-final-title{font-family:'Bricolage Grotesque',sans-serif;font-weight:800;position:relative;
  font-size:clamp(34px,6vw,64px);line-height:.98;letter-spacing:-.035em;margin:14px 0 16px;}
.mb-final-title em{font-family:'Instrument Serif',serif;font-style:italic;font-weight:400;color:var(--cyan);}
.mb-final-sub{position:relative;font-size:16px;color:var(--muted);font-weight:300;margin:0 0 36px;}

/* footer */
.mb-footer{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:14px;
  padding:32px clamp(20px,5vw,56px);border-top:1px solid var(--line);}
.mb-footer-note{font-size:12px;color:var(--faint);letter-spacing:.4px;}

/* reveal */
.reveal{opacity:0;transform:translateY(28px);
  transition:opacity .9s cubic-bezier(.2,.8,.2,1) var(--d,0ms),transform .9s cubic-bezier(.2,.8,.2,1) var(--d,0ms);}
.reveal.is-visible{opacity:1;transform:translateY(0);}

/* responsive */
@media(max-width:920px){
  .mb-hero-grid{grid-template-columns:1fr;gap:48px;}
  .mb-hero-visual{order:2;}
  .mb-steps{grid-template-columns:1fr;gap:32px;}
  .mb-steps-line{display:none;}
}
@media(max-width:860px){
  .mb-stats{grid-template-columns:repeat(2,1fr);gap:34px 24px;}
  .mb-stat{border-left:none;padding-left:0;}
  .mb-bento{grid-template-columns:1fr 1fr;}
}
@media(max-width:560px){
  .mb-bento{grid-template-columns:1fr;}
  .mb-bento-cell.span-2{grid-column:span 1;}
  .mb-cta-row{flex-direction:column;width:100%;}
  .mb-cta-row .mb-magnetic,.mb-cta-row .mb-btn{width:100%;justify-content:center;}
  .mb-trust{gap:10px 18px;}
}
@media(prefers-reduced-motion:reduce){
  .reveal{opacity:1!important;transform:none!important;transition:none;}
  .mb-marquee-track,.mb-scroll-bar i,.mb-receipt-wrap,.mb-receipt,.mb-paid-chip{animation:none!important;}
  .mb-receipt{clip-path:none;}
}
`;
