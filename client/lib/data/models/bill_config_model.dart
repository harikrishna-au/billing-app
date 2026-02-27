/// Bill/receipt configuration fetched from the backend and cached locally.
class BillConfig {
  final String machineId;
  final String orgName;
  final String? tagline;
  final String? logoUrl;
  final String? unitName;
  final String? territory;
  final String? gstNumber;
  final String? posId;
  final double cgstPercent;
  final double sgstPercent;
  final String? footerMessage;
  final String? website;
  final String? tollFree;

  const BillConfig({
    required this.machineId,
    required this.orgName,
    this.tagline,
    this.logoUrl,
    this.unitName,
    this.territory,
    this.gstNumber,
    this.posId,
    this.cgstPercent = 0.0,
    this.sgstPercent = 0.0,
    this.footerMessage,
    this.website,
    this.tollFree,
  });

  static const BillConfig empty = BillConfig(machineId: '', orgName: '');

  factory BillConfig.fromJson(Map<String, dynamic> json) {
    return BillConfig(
      machineId: json['machine_id']?.toString() ?? '',
      orgName: json['org_name']?.toString() ?? '',
      tagline: json['tagline']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      unitName: json['unit_name']?.toString(),
      territory: json['territory']?.toString(),
      gstNumber: json['gst_number']?.toString(),
      posId: json['pos_id']?.toString(),
      cgstPercent: _toDouble(json['cgst_percent']),
      sgstPercent: _toDouble(json['sgst_percent']),
      footerMessage: json['footer_message']?.toString(),
      website: json['website']?.toString(),
      tollFree: json['toll_free']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'machine_id': machineId,
        'org_name': orgName,
        'tagline': tagline,
        'logo_url': logoUrl,
        'unit_name': unitName,
        'territory': territory,
        'gst_number': gstNumber,
        'pos_id': posId,
        'cgst_percent': cgstPercent,
        'sgst_percent': sgstPercent,
        'footer_message': footerMessage,
        'website': website,
        'toll_free': tollFree,
      };

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
