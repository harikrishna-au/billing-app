import { useNavigate } from "react-router-dom";
import { useEffect, useRef } from "react";

const services = [
  {
    icon: "🚤",
    name: "Speed Boat",
    tagline: "Feel the thrill",
    desc: "High-speed rides across open water with certified operators",
    price: "From ₹800",
    color: "#00d4ff",
  },
  {
    icon: "🛵",
    name: "Jet Ski",
    tagline: "Ride the waves",
    desc: "Solo or duo Jet Ski sessions on calm and choppy waters alike",
    price: "From ₹600",
    color: "#00ffb3",
  },
  {
    icon: "🍌",
    name: "Banana Boat",
    tagline: "Group adventures",
    desc: "Fun-filled banana boat rides for groups of up to 6 people",
    price: "From ₹300/person",
    color: "#ffe066",
  },
  {
    icon: "🪂",
    name: "Parasailing",
    tagline: "Touch the sky",
    desc: "Soar 100ft above the sea with panoramic coastal views",
    price: "From ₹1200",
    color: "#ff6b6b",
  },
  {
    icon: "🚣",
    name: "Kayaking",
    tagline: "Paddle your path",
    desc: "Single and double kayaks with guided coastal routes",
    price: "From ₹400",
    color: "#a78bfa",
  },
  {
    icon: "🏄",
    name: "Water Scooter",
    tagline: "Surf & glide",
    desc: "Beginner-friendly water scooter sessions with life jackets",
    price: "From ₹500",
    color: "#f97316",
  },
];

const stats = [
  { value: "10,000+", label: "Happy Customers" },
  { value: "6+", label: "Water Activities" },
  { value: "100%", label: "Safety Record" },
  { value: "5★", label: "Customer Rating" },
];

export default function LandingPage() {
  const navigate = useNavigate();
  const heroRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  // Animated wave canvas
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let animFrame: number;
    let t = 0;

    const resize = () => {
      canvas.width = window.innerWidth;
      canvas.height = 200;
    };
    resize();
    window.addEventListener("resize", resize);

    const draw = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      for (let w = 0; w < 3; w++) {
        ctx.beginPath();
        ctx.moveTo(0, 100);
        for (let x = 0; x <= canvas.width; x += 4) {
          const y =
            50 +
            Math.sin((x / 180 + t + w * 0.8) * Math.PI) * (18 - w * 4) +
            Math.sin((x / 90 + t * 1.3 + w) * Math.PI) * (8 - w * 2);
          ctx.lineTo(x, y);
        }
        ctx.lineTo(canvas.width, 200);
        ctx.lineTo(0, 200);
        ctx.closePath();
        const alpha = 0.15 - w * 0.04;
        ctx.fillStyle = `rgba(0, 212, 255, ${alpha})`;
        ctx.fill();
      }
      t += 0.008;
      animFrame = requestAnimationFrame(draw);
    };
    draw();

    return () => {
      cancelAnimationFrame(animFrame);
      window.removeEventListener("resize", resize);
    };
  }, []);

  // Parallax on hero
  useEffect(() => {
    const el = heroRef.current;
    if (!el) return;
    const onScroll = () => {
      const y = window.scrollY;
      el.style.backgroundPositionY = `${y * 0.35}px`;
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const handleLogin = () => navigate("/login");

  return (
    <div style={{ fontFamily: "'Syne', sans-serif", background: "#040d18", color: "#e8f4ff", overflowX: "hidden" }}>
      {/* Google Fonts */}
      <link
        href="https://fonts.googleapis.com/css2?family=Syne:wght@400;500;600;700;800&family=DM+Sans:ital,wght@0,300;0,400;0,500;1,300&display=swap"
        rel="stylesheet"
      />

      {/* ── NAV ── */}
      <nav style={{
        position: "fixed", top: 0, left: 0, right: 0, zIndex: 100,
        padding: "18px 48px",
        display: "flex", alignItems: "center", justifyContent: "space-between",
        background: "linear-gradient(180deg, rgba(4,13,24,0.95) 0%, transparent 100%)",
        backdropFilter: "blur(0px)",
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div style={{
            width: 36, height: 36, borderRadius: 10,
            background: "linear-gradient(135deg, #00d4ff, #0077ff)",
            display: "flex", alignItems: "center", justifyContent: "center",
            fontSize: 18,
          }}>🌊</div>
          <span style={{ fontWeight: 800, fontSize: 17, letterSpacing: "-0.5px", color: "#fff" }}>
            Water Sports
          </span>
        </div>
        <button
          onClick={handleLogin}
          style={{
            padding: "9px 22px", borderRadius: 50,
            background: "linear-gradient(135deg, #00d4ff, #0077ff)",
            border: "none", color: "#fff", fontFamily: "inherit",
            fontWeight: 700, fontSize: 13, cursor: "pointer",
            letterSpacing: "0.3px",
          }}
        >
          Admin Login →
        </button>
      </nav>

      {/* ── HERO ── */}
      <div
        ref={heroRef}
        style={{
          minHeight: "100vh",
          position: "relative",
          display: "flex", flexDirection: "column",
          alignItems: "center", justifyContent: "center",
          textAlign: "center",
          padding: "120px 24px 80px",
          background:
            "radial-gradient(ellipse 80% 60% at 50% 30%, rgba(0,119,255,0.18) 0%, transparent 70%), " +
            "radial-gradient(ellipse 40% 40% at 80% 80%, rgba(0,212,255,0.1) 0%, transparent 60%), " +
            "#040d18",
        }}
      >
        {/* Floating orbs */}
        <div style={{
          position: "absolute", top: "15%", left: "8%", width: 300, height: 300,
          borderRadius: "50%",
          background: "radial-gradient(circle, rgba(0,212,255,0.08) 0%, transparent 70%)",
          animation: "float 8s ease-in-out infinite",
          pointerEvents: "none",
        }} />
        <div style={{
          position: "absolute", top: "40%", right: "6%", width: 200, height: 200,
          borderRadius: "50%",
          background: "radial-gradient(circle, rgba(0,119,255,0.1) 0%, transparent 70%)",
          animation: "float 6s ease-in-out infinite reverse",
          pointerEvents: "none",
        }} />

        <div style={{
          display: "inline-block", padding: "6px 18px", borderRadius: 50,
          border: "1px solid rgba(0,212,255,0.35)",
          color: "#00d4ff", fontSize: 12, fontWeight: 600,
          letterSpacing: "2px", textTransform: "uppercase",
          marginBottom: 28, fontFamily: "'DM Sans', sans-serif",
        }}>
          Water Sports Experience
        </div>

        <h1 style={{
          fontSize: "clamp(48px, 8vw, 96px)",
          fontWeight: 800,
          lineHeight: 1.0,
          letterSpacing: "-3px",
          margin: "0 0 28px",
          color: "#fff",
          maxWidth: 900,
        }}>
          Ride the<br />
          <span style={{
            background: "linear-gradient(135deg, #00d4ff 0%, #0077ff 50%, #a78bfa 100%)",
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
          }}>Ocean.</span>
        </h1>

        <p style={{
          fontSize: "clamp(16px, 2vw, 20px)", color: "rgba(232,244,255,0.6)",
          maxWidth: 520, lineHeight: 1.65, fontFamily: "'DM Sans', sans-serif",
          fontWeight: 300, margin: "0 0 48px",
        }}>
          Premium water sports adventures — from high-speed jet ski rides to serene kayaking sessions.
          Professionally operated, safety-first, unforgettably fun.
        </p>

        <div style={{ display: "flex", gap: 14, flexWrap: "wrap", justifyContent: "center" }}>
          <button
            onClick={() => document.getElementById("services")?.scrollIntoView({ behavior: "smooth" })}
            style={{
              padding: "15px 36px", borderRadius: 50,
              background: "linear-gradient(135deg, #00d4ff, #0077ff)",
              border: "none", color: "#fff", fontFamily: "inherit",
              fontWeight: 700, fontSize: 15, cursor: "pointer",
              boxShadow: "0 0 40px rgba(0,212,255,0.3)",
              transition: "transform 0.2s, box-shadow 0.2s",
            }}
            onMouseOver={e => {
              (e.currentTarget as HTMLButtonElement).style.transform = "translateY(-2px)";
              (e.currentTarget as HTMLButtonElement).style.boxShadow = "0 0 60px rgba(0,212,255,0.5)";
            }}
            onMouseOut={e => {
              (e.currentTarget as HTMLButtonElement).style.transform = "translateY(0)";
              (e.currentTarget as HTMLButtonElement).style.boxShadow = "0 0 40px rgba(0,212,255,0.3)";
            }}
          >
            Explore Activities
          </button>
          <button
            onClick={handleLogin}
            style={{
              padding: "15px 36px", borderRadius: 50,
              background: "transparent",
              border: "1.5px solid rgba(0,212,255,0.4)",
              color: "#00d4ff", fontFamily: "inherit",
              fontWeight: 600, fontSize: 15, cursor: "pointer",
              transition: "all 0.2s",
            }}
            onMouseOver={e => {
              (e.currentTarget as HTMLButtonElement).style.background = "rgba(0,212,255,0.08)";
              (e.currentTarget as HTMLButtonElement).style.borderColor = "#00d4ff";
            }}
            onMouseOut={e => {
              (e.currentTarget as HTMLButtonElement).style.background = "transparent";
              (e.currentTarget as HTMLButtonElement).style.borderColor = "rgba(0,212,255,0.4)";
            }}
          >
            Staff Login
          </button>
        </div>

        {/* Wave canvas */}
        <canvas
          ref={canvasRef}
          style={{ position: "absolute", bottom: 0, left: 0, right: 0, opacity: 0.8 }}
        />
      </div>

      {/* ── STATS ── */}
      <div style={{
        padding: "60px 48px",
        background: "rgba(0,119,255,0.06)",
        borderTop: "1px solid rgba(0,212,255,0.1)",
        borderBottom: "1px solid rgba(0,212,255,0.1)",
      }}>
        <div style={{
          maxWidth: 900, margin: "0 auto",
          display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))",
          gap: 32, textAlign: "center",
        }}>
          {stats.map(s => (
            <div key={s.label}>
              <div style={{ fontSize: "clamp(28px, 4vw, 40px)", fontWeight: 800, color: "#00d4ff", letterSpacing: "-1px" }}>
                {s.value}
              </div>
              <div style={{ fontSize: 13, color: "rgba(232,244,255,0.5)", fontFamily: "'DM Sans', sans-serif", marginTop: 4, letterSpacing: "0.5px" }}>
                {s.label}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* ── SERVICES ── */}
      <div id="services" style={{ padding: "100px 24px", maxWidth: 1100, margin: "0 auto" }}>
        <div style={{ textAlign: "center", marginBottom: 72 }}>
          <div style={{
            display: "inline-block", padding: "5px 16px", borderRadius: 50,
            border: "1px solid rgba(0,212,255,0.25)",
            color: "#00d4ff", fontSize: 11, fontWeight: 600,
            letterSpacing: "2.5px", textTransform: "uppercase",
            marginBottom: 20, fontFamily: "'DM Sans', sans-serif",
          }}>
            What We Offer
          </div>
          <h2 style={{ fontSize: "clamp(32px, 5vw, 56px)", fontWeight: 800, margin: 0, letterSpacing: "-2px", color: "#fff" }}>
            Choose Your<br />
            <span style={{ color: "#00d4ff" }}>Adventure</span>
          </h2>
        </div>

        <div style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))",
          gap: 20,
        }}>
          {services.map((s) => (
            <ServiceCard key={s.name} {...s} />
          ))}
        </div>
      </div>

      {/* ── WHY US ── */}
      <div style={{
        padding: "80px 48px",
        background: "linear-gradient(135deg, rgba(0,119,255,0.07) 0%, rgba(0,212,255,0.04) 100%)",
        borderTop: "1px solid rgba(0,212,255,0.08)",
      }}>
        <div style={{ maxWidth: 1000, margin: "0 auto" }}>
          <div style={{ textAlign: "center", marginBottom: 60 }}>
            <h2 style={{ fontSize: "clamp(28px, 4vw, 46px)", fontWeight: 800, margin: 0, letterSpacing: "-1.5px", color: "#fff" }}>
              Why Choose Us?
            </h2>
          </div>
          <div style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
            gap: 28,
          }}>
            {[
              { icon: "🛡️", title: "Safety First", desc: "Certified instructors, life jackets provided, regular equipment maintenance" },
              { icon: "⚡", title: "Instant Booking", desc: "Walk-in or advance bookings — instant digital receipts on the spot" },
              { icon: "🏆", title: "Experienced Team", desc: "Trained water sports professionals with years of coastal expertise" },
              { icon: "💳", title: "Easy Payments", desc: "Cash, Card, or UPI — all payment modes accepted with GST invoices" },
            ].map(w => (
              <div key={w.title} style={{
                padding: "28px 24px",
                borderRadius: 16,
                border: "1px solid rgba(255,255,255,0.06)",
                background: "rgba(255,255,255,0.02)",
              }}>
                <div style={{ fontSize: 32, marginBottom: 14 }}>{w.icon}</div>
                <div style={{ fontWeight: 700, fontSize: 16, marginBottom: 8, color: "#fff", letterSpacing: "-0.3px" }}>{w.title}</div>
                <div style={{ fontSize: 13.5, color: "rgba(232,244,255,0.5)", lineHeight: 1.6, fontFamily: "'DM Sans', sans-serif", fontWeight: 300 }}>{w.desc}</div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* ── CTA BANNER ── */}
      <div style={{ padding: "100px 24px", textAlign: "center" }}>
        <div style={{
          maxWidth: 680, margin: "0 auto",
          padding: "64px 48px",
          borderRadius: 28,
          border: "1px solid rgba(0,212,255,0.2)",
          background: "linear-gradient(135deg, rgba(0,119,255,0.12) 0%, rgba(0,212,255,0.06) 100%)",
          position: "relative", overflow: "hidden",
        }}>
          {/* glow */}
          <div style={{
            position: "absolute", top: "-40%", left: "50%", transform: "translateX(-50%)",
            width: 400, height: 400, borderRadius: "50%",
            background: "radial-gradient(circle, rgba(0,212,255,0.12) 0%, transparent 70%)",
            pointerEvents: "none",
          }} />
          <h2 style={{ fontSize: "clamp(28px, 4vw, 44px)", fontWeight: 800, margin: "0 0 16px", letterSpacing: "-1.5px", color: "#fff", position: "relative" }}>
            Ready to make<br />a splash?
          </h2>
          <p style={{ fontSize: 16, color: "rgba(232,244,255,0.55)", marginBottom: 36, lineHeight: 1.6, fontFamily: "'DM Sans', sans-serif", fontWeight: 300, position: "relative" }}>
            Book your activity today — groups, families, solo adventurers all welcome.
          </p>
          <button
            onClick={handleLogin}
            style={{
              padding: "15px 40px", borderRadius: 50,
              background: "linear-gradient(135deg, #00d4ff, #0077ff)",
              border: "none", color: "#fff", fontFamily: "inherit",
              fontWeight: 700, fontSize: 15, cursor: "pointer",
              boxShadow: "0 0 50px rgba(0,212,255,0.35)",
              position: "relative",
            }}
          >
            Staff Portal →
          </button>
        </div>
      </div>

      {/* ── FOOTER ── */}
      <footer style={{
        padding: "36px 48px",
        borderTop: "1px solid rgba(255,255,255,0.06)",
        display: "flex", alignItems: "center", justifyContent: "space-between",
        flexWrap: "wrap", gap: 12,
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div style={{
            width: 30, height: 30, borderRadius: 8,
            background: "linear-gradient(135deg, #00d4ff, #0077ff)",
            display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14,
          }}>🌊</div>
          <span style={{ fontWeight: 700, fontSize: 14, color: "#fff" }}>Water Sports Pvt Ltd</span>
        </div>
        <div style={{ fontSize: 12, color: "rgba(232,244,255,0.3)", fontFamily: "'DM Sans', sans-serif" }}>
          © {new Date().getFullYear()} · All rights reserved · GST Registered
        </div>
      </footer>

      <style>{`
        @keyframes float {
          0%, 100% { transform: translateY(0px); }
          50% { transform: translateY(-20px); }
        }
      `}</style>
    </div>
  );
}

function ServiceCard({ icon, name, tagline, desc, price, color }: {
  icon: string; name: string; tagline: string; desc: string; price: string; color: string;
}) {
  return (
    <div
      style={{
        padding: "28px 26px",
        borderRadius: 20,
        border: "1px solid rgba(255,255,255,0.06)",
        background: "rgba(255,255,255,0.02)",
        cursor: "default",
        transition: "transform 0.25s, border-color 0.25s, box-shadow 0.25s",
        position: "relative", overflow: "hidden",
      }}
      onMouseOver={e => {
        const el = e.currentTarget as HTMLDivElement;
        el.style.transform = "translateY(-4px)";
        el.style.borderColor = `${color}40`;
        el.style.boxShadow = `0 12px 40px ${color}18`;
      }}
      onMouseOut={e => {
        const el = e.currentTarget as HTMLDivElement;
        el.style.transform = "translateY(0)";
        el.style.borderColor = "rgba(255,255,255,0.06)";
        el.style.boxShadow = "none";
      }}
    >
      <div style={{
        position: "absolute", top: -20, right: -20, width: 80, height: 80,
        borderRadius: "50%",
        background: `radial-gradient(circle, ${color}15 0%, transparent 70%)`,
        pointerEvents: "none",
      }} />
      <div style={{ fontSize: 36, marginBottom: 14 }}>{icon}</div>
      <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: "2px", textTransform: "uppercase", color, marginBottom: 6, fontFamily: "'DM Sans', sans-serif" }}>
        {tagline}
      </div>
      <div style={{ fontSize: 21, fontWeight: 800, color: "#fff", letterSpacing: "-0.5px", marginBottom: 10 }}>{name}</div>
      <div style={{ fontSize: 13.5, color: "rgba(232,244,255,0.45)", lineHeight: 1.6, fontFamily: "'DM Sans', sans-serif", fontWeight: 300, marginBottom: 20 }}>{desc}</div>
      <div style={{
        display: "inline-block", padding: "6px 14px", borderRadius: 50,
        border: `1px solid ${color}40`,
        color, fontSize: 12, fontWeight: 700,
      }}>
        {price}
      </div>
    </div>
  );
}
