import { useNavigate } from "react-router-dom";
import { useState } from "react";

export default function ContactPage() {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({
    name: "",
    email: "",
    company: "",
    message: "",
  });
  const [submitted, setSubmitted] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // For now, just show success - in real app, send to backend
    setSubmitted(true);
    setTimeout(() => {
      navigate("/");
    }, 2000);
  };

  return (
    <div className="contact-root">
      <style>{CONTACT_CSS}</style>

      {/* NAV */}
      <nav className="contact-nav">
        <button onClick={() => navigate("/")} className="contact-back">
          ← Back to MIT Billing
        </button>
      </nav>

      {/* HERO */}
      <header className="contact-hero">
        <div className="contact-hero-content">
          <p className="contact-eyebrow">Get in Touch</p>
          <h1 className="contact-title">Let's talk <em>billing.</em></h1>
          <p className="contact-subtitle">
            Have questions? Want to schedule a demo? Ready to get started?<br />
            We're here to help.
          </p>
        </div>
      </header>

      {/* CONTENT */}
      <div className="contact-container">
        <div className="contact-grid">
          {/* FORM */}
          <div className="contact-form-section">
            {submitted ? (
              <div className="contact-success">
                <div className="contact-success-icon">✓</div>
                <h3 className="contact-success-title">Message Sent!</h3>
                <p className="contact-success-text">
                  Thanks for reaching out. We'll get back to you shortly.
                </p>
                <p className="contact-redirect">Redirecting to home...</p>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="contact-form">
                <div className="contact-form-group">
                  <label className="contact-label">Your Name</label>
                  <input
                    type="text"
                    name="name"
                    value={formData.name}
                    onChange={handleChange}
                    required
                    className="contact-input"
                    placeholder="Raj Kumar"
                  />
                </div>

                <div className="contact-form-group">
                  <label className="contact-label">Email Address</label>
                  <input
                    type="email"
                    name="email"
                    value={formData.email}
                    onChange={handleChange}
                    required
                    className="contact-input"
                    placeholder="raj@business.com"
                  />
                </div>

                <div className="contact-form-group">
                  <label className="contact-label">Company / Shop Name</label>
                  <input
                    type="text"
                    name="company"
                    value={formData.company}
                    onChange={handleChange}
                    className="contact-input"
                    placeholder="Your Business Name"
                  />
                </div>

                <div className="contact-form-group">
                  <label className="contact-label">Message</label>
                  <textarea
                    name="message"
                    value={formData.message}
                    onChange={handleChange}
                    required
                    className="contact-textarea"
                    placeholder="Tell us about your billing needs..."
                    rows={5}
                  />
                </div>

                <button type="submit" className="contact-btn">
                  Send Message
                </button>
              </form>
            )}
          </div>

          {/* INFO */}
          <div className="contact-info-section">
            <div className="contact-info-card">
              <div className="contact-info-icon">✉️</div>
              <h3 className="contact-info-title">Email</h3>
              <p className="contact-info-text">
                <a href="mailto:nallanahk@gmail.com">nallanahk@gmail.com</a>
              </p>
              <p className="contact-info-desc">Get a response within 24 hours</p>
            </div>

            <div className="contact-info-card">
              <div className="contact-info-icon">📱</div>
              <h3 className="contact-info-title">Support</h3>
              <p className="contact-info-text">Live chat, email, phone support</p>
              <p className="contact-info-desc">Available 9 AM - 6 PM IST, Mon-Sat</p>
            </div>

            <div className="contact-info-card">
              <div className="contact-info-icon">🚀</div>
              <h3 className="contact-info-title">Enterprise</h3>
              <p className="contact-info-text">Custom solutions & pricing</p>
              <p className="contact-info-desc">For large deployments & integrations</p>
            </div>

            <div className="contact-info-card">
              <div className="contact-info-icon">📍</div>
              <h3 className="contact-info-title">Location</h3>
              <p className="contact-info-text">India</p>
              <p className="contact-info-desc">Built for Indian retail, serving nationwide</p>
            </div>
          </div>
        </div>
      </div>

      {/* FOOTER */}
      <footer className="contact-footer">
        <button onClick={() => navigate("/")} className="contact-footer-link">
          ← Back to Home
        </button>
      </footer>
    </div>
  );
}

const CONTACT_CSS = `
.contact-root {
  --bg: #070912;
  --ink: #eef1ff;
  --indigo: #7c6cff;
  --cyan: #22d3ee;
  --muted: rgba(238, 241, 255, 0.55);
  --faint: rgba(238, 241, 255, 0.34);
  --line: rgba(140, 150, 220, 0.14);

  font-family: 'DM Sans', sans-serif;
  color: var(--ink);
  background: linear-gradient(180deg, #0b0e1c 0%, #090b16 30%, #070912 70%, #05060d 100%);
  min-height: 100vh;
  overflow-x: hidden;
}

/* NAV */
.contact-nav {
  padding: 20px clamp(20px, 5vw, 56px);
  border-bottom: 1px solid var(--line);
  background: linear-gradient(180deg, rgba(7, 9, 18, 0.72), transparent);
}

.contact-back {
  background: none;
  border: none;
  color: var(--cyan);
  font-family: 'DM Sans', sans-serif;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  transition: color 0.3s;
  padding: 0;
}

.contact-back:hover {
  color: #fff;
}

/* HERO */
.contact-hero {
  padding: clamp(60px, 8vw, 100px) clamp(20px, 5vw, 56px);
  text-align: center;
  background: radial-gradient(ellipse 80% 60% at 50% 30%, rgba(124, 108, 255, 0.1) 0%, transparent 60%);
}

.contact-hero-content {
  max-width: 800px;
  margin: 0 auto;
}

.contact-eyebrow {
  font-size: 12px;
  letter-spacing: 3px;
  text-transform: uppercase;
  color: var(--cyan);
  margin: 0 0 20px;
  font-weight: 600;
}

.contact-title {
  font-family: 'Bricolage Grotesque', sans-serif;
  font-size: clamp(40px, 6vw, 72px);
  font-weight: 800;
  letter-spacing: -0.03em;
  margin: 0 0 16px;
  line-height: 1.1;
}

.contact-title em {
  font-family: 'Instrument Serif', serif;
  font-style: italic;
  font-weight: 400;
  color: var(--cyan);
}

.contact-subtitle {
  font-size: 16px;
  color: var(--muted);
  line-height: 1.6;
  margin: 0;
  max-width: 500px;
  margin-left: auto;
  margin-right: auto;
}

/* CONTAINER */
.contact-container {
  max-width: 1100px;
  margin: 0 auto;
  padding: clamp(40px, 6vw, 80px) clamp(20px, 5vw, 56px);
}

.contact-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: clamp(40px, 6vw, 80px);
  align-items: start;
}

/* FORM */
.contact-form-section {
  padding: 40px;
  border-radius: 24px;
  border: 1.5px solid var(--line);
  background: linear-gradient(160deg, rgba(255, 255, 255, 0.035), rgba(255, 255, 255, 0.01));
}

.contact-form {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.contact-form-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.contact-label {
  font-size: 14px;
  font-weight: 600;
  color: #fff;
  letter-spacing: 0.3px;
}

.contact-input,
.contact-textarea {
  padding: 12px 16px;
  border-radius: 12px;
  border: 1px solid var(--line);
  background: rgba(255, 255, 255, 0.05);
  color: var(--ink);
  font-family: 'DM Sans', sans-serif;
  font-size: 14px;
  transition: border-color 0.3s, background 0.3s;
}

.contact-input:focus,
.contact-textarea:focus {
  outline: none;
  border-color: var(--cyan);
  background: rgba(255, 255, 255, 0.08);
}

.contact-textarea {
  resize: vertical;
  min-height: 120px;
}

.contact-btn {
  padding: 14px 32px;
  border-radius: 12px;
  border: none;
  background: linear-gradient(135deg, var(--indigo), #5b8cff 60%, var(--cyan));
  color: #fff;
  font-family: 'DM Sans', sans-serif;
  font-weight: 700;
  font-size: 14px;
  cursor: pointer;
  transition: box-shadow 0.3s;
  box-shadow: 0 8px 40px rgba(124, 108, 255, 0.32);
}

.contact-btn:hover {
  box-shadow: 0 12px 60px rgba(124, 108, 255, 0.55);
}

/* SUCCESS */
.contact-success {
  text-align: center;
  padding: 40px;
}

.contact-success-icon {
  font-size: 48px;
  margin-bottom: 20px;
  animation: contactSuccess 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275);
}

.contact-success-title {
  font-family: 'Bricolage Grotesque', sans-serif;
  font-size: 28px;
  font-weight: 800;
  margin: 0 0 12px;
  color: #fff;
}

.contact-success-text {
  font-size: 16px;
  color: var(--muted);
  margin: 0 0 20px;
}

.contact-redirect {
  font-size: 13px;
  color: var(--faint);
  margin: 0;
}

@keyframes contactSuccess {
  0% { transform: scale(0) rotate(-180deg); opacity: 0; }
  100% { transform: scale(1) rotate(0); opacity: 1; }
}

/* INFO CARDS */
.contact-info-section {
  display: grid;
  grid-template-columns: 1fr;
  gap: 20px;
}

.contact-info-card {
  padding: 28px;
  border-radius: 16px;
  border: 1.5px solid var(--line);
  background: linear-gradient(160deg, rgba(255, 255, 255, 0.04), rgba(255, 255, 255, 0.01));
  transition: transform 0.3s, border-color 0.3s;
}

.contact-info-card:hover {
  transform: translateY(-4px);
  border-color: rgba(124, 108, 255, 0.36);
}

.contact-info-icon {
  font-size: 32px;
  margin-bottom: 12px;
}

.contact-info-title {
  font-family: 'Bricolage Grotesque', sans-serif;
  font-size: 18px;
  font-weight: 700;
  margin: 0 0 8px;
  color: #fff;
}

.contact-info-text {
  font-size: 15px;
  color: var(--cyan);
  margin: 0 0 6px;
  font-weight: 600;
}

.contact-info-text a {
  color: var(--cyan);
  text-decoration: none;
  transition: color 0.3s;
}

.contact-info-text a:hover {
  color: #fff;
}

.contact-info-desc {
  font-size: 13px;
  color: var(--faint);
  margin: 0;
  line-height: 1.5;
}

/* FOOTER */
.contact-footer {
  padding: 32px clamp(20px, 5vw, 56px);
  border-top: 1px solid var(--line);
  text-align: center;
}

.contact-footer-link {
  background: none;
  border: none;
  color: var(--cyan);
  font-family: 'DM Sans', sans-serif;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  transition: color 0.3s;
  padding: 0;
}

.contact-footer-link:hover {
  color: #fff;
}

/* RESPONSIVE */
@media (max-width: 768px) {
  .contact-grid {
    grid-template-columns: 1fr;
  }

  .contact-form-section {
    padding: 28px;
  }

  .contact-title {
    font-size: clamp(32px, 5vw, 48px);
  }
}

@media (prefers-reduced-motion: reduce) {
  * {
    animation: none !important;
    transition: none !important;
  }
}
`;
