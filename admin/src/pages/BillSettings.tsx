import { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";
import { useToast } from "@/components/ui/use-toast";
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";
import { ArrowLeft, Save, Loader2, FileText, Building2, Receipt, Phone } from "lucide-react";
import { configApi, machinesApi } from "@/lib/api";
import type { BillConfigUpdate } from "@/lib/api";

// ─── Field group component ────────────────────────────────────────────────────
function Section({ icon: Icon, title, children }: {
  icon: React.ElementType;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="rounded-xl border bg-card p-6 space-y-4">
      <div className="flex items-center gap-2 text-sm font-semibold text-muted-foreground uppercase tracking-wide">
        <Icon className="h-4 w-4" />
        {title}
      </div>
      <Separator />
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">{children}</div>
    </div>
  );
}

function Field({ label, id, type = "text", placeholder, value, onChange }: {
  label: string;
  id: string;
  type?: string;
  placeholder?: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div className="space-y-1.5">
      <Label htmlFor={id}>{label}</Label>
      <Input
        id={id}
        type={type}
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      />
    </div>
  );
}

// ─── Bill preview ─────────────────────────────────────────────────────────────
function BillPreview({ form }: { form: BillConfigUpdate }) {
  const cgst = Number(form.cgst_percent ?? 0);
  const sgst = Number(form.sgst_percent ?? 0);
  const sampleTotal = 300;
  const base = sampleTotal / (1 + cgst / 100 + sgst / 100);
  const cgstAmt = base * (cgst / 100);
  const sgstAmt = base * (sgst / 100);

  return (
    <div className="rounded-xl border bg-muted/30 p-6 font-mono text-xs leading-5 space-y-0.5 select-none">
      <p className="text-center font-bold text-sm">{form.org_name || "Organization Name"}</p>
      {form.tagline && <p className="text-center text-muted-foreground">{form.tagline}</p>}
      <p className="text-center text-muted-foreground">{"=".repeat(32)}</p>
      {form.unit_name && <p>Unit: {form.unit_name}</p>}
      {form.territory && <p>Territory: {form.territory}</p>}
      {form.gst_number && <p>GST: {form.gst_number}</p>}
      {form.pos_id && <p>POS ID: {form.pos_id}</p>}
      <p>Date: {new Date().toLocaleString()}</p>
      <p className="text-center text-muted-foreground">{"=".repeat(32)}</p>
      <p className="text-center font-bold">INVOICE</p>
      <p className="text-center text-muted-foreground">{"=".repeat(32)}</p>
      <div className="flex justify-between">
        <span className="flex-1">Ticket Name</span>
        <span className="w-12 text-right">Price</span>
        <span className="w-8 text-right">Qty</span>
        <span className="w-14 text-right">Amt</span>
      </div>
      <p className="text-muted-foreground">{"-".repeat(32)}</p>
      <div className="flex justify-between">
        <span className="flex-1">Sample Item</span>
        <span className="w-12 text-right">100</span>
        <span className="w-8 text-right">3</span>
        <span className="w-14 text-right">300.00</span>
      </div>
      <p className="text-muted-foreground">{"=".repeat(32)}</p>
      {cgst > 0 && (
        <div className="flex justify-between">
          <span>CGST @{cgst.toFixed(1)}%</span>
          <span>{cgstAmt.toFixed(2)}</span>
        </div>
      )}
      {sgst > 0 && (
        <div className="flex justify-between">
          <span>SGST @{sgst.toFixed(1)}%</span>
          <span>{sgstAmt.toFixed(2)}</span>
        </div>
      )}
      <p className="text-muted-foreground">{"=".repeat(32)}</p>
      <div className="flex justify-between font-bold">
        <span>Total</span>
        <span>{sampleTotal.toFixed(2)}</span>
      </div>
      <p>Mode: UPI</p>
      <p className="text-muted-foreground text-[10px]">Inclusive of all taxes</p>
      <p className="text-center text-muted-foreground">{"=".repeat(32)}</p>
      <p className="text-center">{form.footer_message || "Thank you. Visit again"}</p>
      {form.website && <p className="text-center text-muted-foreground">{form.website}</p>}
      {form.toll_free && <p className="text-center text-muted-foreground">{form.toll_free}</p>}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
const EMPTY_FORM: BillConfigUpdate = {
  org_name: "",
  tagline: "",
  logo_url: "",
  unit_name: "",
  territory: "",
  gst_number: "",
  pos_id: "",
  cgst_percent: 0,
  sgst_percent: 0,
  footer_message: "Thank you. Visit again",
  website: "",
  toll_free: "",
};

export default function BillSettings() {
  const { id: machineId } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { toast } = useToast();
  const qc = useQueryClient();

  const [form, setForm] = useState<BillConfigUpdate>(EMPTY_FORM);

  // Fetch machine name for breadcrumb
  const { data: machine } = useQuery({
    queryKey: ["machine", machineId],
    queryFn: () => machinesApi.getById(machineId!),
    enabled: !!machineId,
  });

  // Fetch existing config
  const { data: config, isLoading } = useQuery({
    queryKey: ["bill-config", machineId],
    queryFn: () => configApi.getByMachine(machineId!),
    enabled: !!machineId,
  });

  // Populate form when config loads
  useEffect(() => {
    if (config) {
      setForm({
        org_name: config.org_name ?? "",
        tagline: config.tagline ?? "",
        logo_url: config.logo_url ?? "",
        unit_name: config.unit_name ?? "",
        territory: config.territory ?? "",
        gst_number: config.gst_number ?? "",
        pos_id: config.pos_id ?? "",
        cgst_percent: config.cgst_percent ?? 0,
        sgst_percent: config.sgst_percent ?? 0,
        footer_message: config.footer_message ?? "Thank you. Visit again",
        website: config.website ?? "",
        toll_free: config.toll_free ?? "",
      });
    }
  }, [config]);

  // Save mutation
  const saveMutation = useMutation({
    mutationFn: () => configApi.upsert(machineId!, form),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["bill-config", machineId] });
      toast({ title: "Saved", description: "Bill configuration updated successfully." });
    },
    onError: (err: any) => {
      toast({
        title: "Save failed",
        description: err?.response?.data?.error?.message ?? "Something went wrong.",
        variant: "destructive",
      });
    },
  });

  const set = (key: keyof BillConfigUpdate) => (v: string) =>
    setForm((f) => ({ ...f, [key]: v }));

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
        {/* Breadcrumb */}
        <Breadcrumb>
          <BreadcrumbList>
            <BreadcrumbItem>
              <BreadcrumbLink href="/clients">Machines</BreadcrumbLink>
            </BreadcrumbItem>
            <BreadcrumbSeparator />
            <BreadcrumbItem>
              <BreadcrumbLink href={`/clients/${machineId}`}>
                {machine?.name ?? machineId}
              </BreadcrumbLink>
            </BreadcrumbItem>
            <BreadcrumbSeparator />
            <BreadcrumbItem>
              <BreadcrumbPage>Bill Settings</BreadcrumbPage>
            </BreadcrumbItem>
          </BreadcrumbList>
        </Breadcrumb>

        {/* Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Button variant="ghost" size="icon" onClick={() => navigate(`/clients/${machineId}`)}>
              <ArrowLeft className="h-4 w-4" />
            </Button>
            <div>
              <h1 className="text-2xl font-bold tracking-tight">Bill Settings</h1>
              <p className="text-sm text-muted-foreground mt-0.5">
                Configure the printed receipt layout for this machine.
              </p>
            </div>
          </div>
          <Button
            onClick={() => saveMutation.mutate()}
            disabled={saveMutation.isPending}
            className="gap-2"
          >
            {saveMutation.isPending ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Save className="h-4 w-4" />
            )}
            Save changes
          </Button>
        </div>

        {/* Two-column layout: form left, preview right */}
        <div className="grid grid-cols-1 xl:grid-cols-[1fr_320px] gap-6 items-start">
          {/* Form */}
          <div className="space-y-6">
            {/* Header / Branding */}
            <Section icon={Building2} title="Organisation & Branding">
              <Field
                label="Organisation name"
                id="org_name"
                placeholder="aptDC"
                value={form.org_name ?? ""}
                onChange={set("org_name")}
              />
              <Field
                label="Tagline"
                id="tagline"
                placeholder="SIMPLE INDIA"
                value={form.tagline ?? ""}
                onChange={set("tagline")}
              />
              <div className="md:col-span-2">
                <Field
                  label="Logo URL (optional)"
                  id="logo_url"
                  placeholder="https://…/logo.png"
                  value={form.logo_url ?? ""}
                  onChange={set("logo_url")}
                />
              </div>
            </Section>

            {/* Unit / location details */}
            <Section icon={FileText} title="Unit Details">
              <Field
                label="Unit name"
                id="unit_name"
                placeholder="Thatipudi 01"
                value={form.unit_name ?? ""}
                onChange={set("unit_name")}
              />
              <Field
                label="Territory"
                id="territory"
                placeholder="VISAKHAPATNAM"
                value={form.territory ?? ""}
                onChange={set("territory")}
              />
              <Field
                label="GST number"
                id="gst_number"
                placeholder="37AABCW7270L1ZT"
                value={form.gst_number ?? ""}
                onChange={set("gst_number")}
              />
              <Field
                label="POS ID"
                id="pos_id"
                placeholder="tdpdi04"
                value={form.pos_id ?? ""}
                onChange={set("pos_id")}
              />
            </Section>

            {/* Tax */}
            <Section icon={Receipt} title="Tax Rates">
              <div className="space-y-1.5">
                <Label htmlFor="cgst">CGST (%)</Label>
                <Input
                  id="cgst"
                  type="number"
                  min={0}
                  max={100}
                  step={0.5}
                  placeholder="9.0"
                  value={form.cgst_percent ?? ""}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, cgst_percent: parseFloat(e.target.value) || 0 }))
                  }
                />
                <p className="text-xs text-muted-foreground">Tax is treated as inclusive of the sale price.</p>
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="sgst">SGST (%)</Label>
                <Input
                  id="sgst"
                  type="number"
                  min={0}
                  max={100}
                  step={0.5}
                  placeholder="9.0"
                  value={form.sgst_percent ?? ""}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, sgst_percent: parseFloat(e.target.value) || 0 }))
                  }
                />
              </div>
            </Section>

            {/* Footer */}
            <Section icon={Phone} title="Footer">
              <div className="md:col-span-2">
                <Field
                  label="Thank-you message"
                  id="footer_message"
                  placeholder="Thank you. Visit again"
                  value={form.footer_message ?? ""}
                  onChange={set("footer_message")}
                />
              </div>
              <Field
                label="Website"
                id="website"
                placeholder="www.tourism.ap.gov.in"
                value={form.website ?? ""}
                onChange={set("website")}
              />
              <Field
                label="Toll-free number"
                id="toll_free"
                placeholder="1800-42-545454"
                value={form.toll_free ?? ""}
                onChange={set("toll_free")}
              />
            </Section>
          </div>

          {/* Live preview */}
          <div className="space-y-3 sticky top-6">
            <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">
              Receipt preview
            </p>
            <BillPreview form={form} />
            <p className="text-xs text-muted-foreground text-center">
              Sample values · actual items &amp; amounts will differ
            </p>
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
