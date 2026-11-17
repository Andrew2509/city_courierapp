class WalletApiException implements Exception {
  final String message;
  final String? errorCode;
  final int? statusCode;

  const WalletApiException(
    this.message, {
    this.errorCode,
    this.statusCode,
  });

  @override
  String toString() => message;
}

class CustomerWalletSummary {
  final int walletId;
  final String walletType;
  final String currency;
  final String status;
  final bool isFrozen;
  final String? freezeReason;
  final int availableBalance;
  final int pendingBalance;
  final int reservedBalance;
  final int totalCredited;
  final int totalDebited;
  final String mode;
  final bool isSandboxOrDemo;
  final String activePaymentProvider;
  final bool withdrawalEnabled;
  final String? withdrawalBlockedReason;
  final int withdrawalMinIdr;
  final int withdrawalMaxIdr;
  final int topupMinIdr;
  final int topupMaxIdr;

  const CustomerWalletSummary({
    required this.walletId,
    required this.walletType,
    required this.currency,
    required this.status,
    required this.isFrozen,
    this.freezeReason,
    required this.availableBalance,
    required this.pendingBalance,
    required this.reservedBalance,
    required this.totalCredited,
    required this.totalDebited,
    required this.mode,
    required this.isSandboxOrDemo,
    required this.activePaymentProvider,
    required this.withdrawalEnabled,
    this.withdrawalBlockedReason,
    required this.withdrawalMinIdr,
    required this.withdrawalMaxIdr,
    required this.topupMinIdr,
    required this.topupMaxIdr,
  });

  factory CustomerWalletSummary.fromJson(Map<String, dynamic> json) {
    final wd = (json['withdrawal_policy'] as Map?)?.cast<String, dynamic>() ?? {};
    final topup = (json['topup_policy'] as Map?)?.cast<String, dynamic>() ?? {};
    return CustomerWalletSummary(
      walletId: _asInt(json['wallet_id']),
      walletType: (json['wallet_type'] ?? 'customer').toString(),
      currency: (json['currency'] ?? 'IDR').toString(),
      status: (json['status'] ?? 'active').toString(),
      isFrozen: json['is_frozen'] == true,
      freezeReason: json['freeze_reason']?.toString(),
      availableBalance: _asInt(json['available_balance']),
      pendingBalance: _asInt(json['pending_balance']),
      reservedBalance: _asInt(json['reserved_balance']),
      totalCredited: _asInt(json['total_credited']),
      totalDebited: _asInt(json['total_debited']),
      mode: (json['mode'] ?? 'sandbox').toString(),
      isSandboxOrDemo: json['is_sandbox_or_demo'] != false,
      activePaymentProvider: (json['active_payment_provider'] ?? 'mock').toString(),
      withdrawalEnabled: wd['enabled'] == true,
      withdrawalBlockedReason: wd['blocked_reason']?.toString(),
      withdrawalMinIdr: _asInt(wd['min_amount_idr'], fallback: 10000),
      withdrawalMaxIdr: _asInt(wd['max_amount_idr'], fallback: 5000000),
      topupMinIdr: _asInt(topup['min_amount_idr'], fallback: 10000),
      topupMaxIdr: _asInt(topup['max_amount_idr'], fallback: 10000000),
    );
  }
}

class WalletTransactionV1 {
  final int id;
  final String type;
  final String direction;
  final int amount;
  final int signedAmount;
  final int? balanceAfter;
  final String status;
  final String? referenceId;
  final String description;
  final String mode;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const WalletTransactionV1({
    required this.id,
    required this.type,
    required this.direction,
    required this.amount,
    required this.signedAmount,
    this.balanceAfter,
    required this.status,
    this.referenceId,
    required this.description,
    required this.mode,
    required this.metadata,
    this.createdAt,
  });

  bool get isCredit => direction == 'credit' || signedAmount >= 0;

  factory WalletTransactionV1.fromJson(Map<String, dynamic> json) {
    return WalletTransactionV1(
      id: _asInt(json['id']),
      type: (json['type'] ?? '').toString(),
      direction: (json['direction'] ?? 'credit').toString(),
      amount: _asInt(json['amount']),
      signedAmount: _asInt(json['signed_amount']),
      balanceAfter: json['balance_after'] != null ? _asInt(json['balance_after']) : null,
      status: (json['status'] ?? 'completed').toString(),
      referenceId: json['reference_id']?.toString(),
      description: (json['description'] ?? '').toString(),
      mode: (json['mode'] ?? 'sandbox').toString(),
      metadata: (json['metadata'] is Map) ? Map<String, dynamic>.from(json['metadata'] as Map) : const {},
      createdAt: _parseDate(json['created_at']),
    );
  }
}

class TopupMethodOption {
  final String paymentType;
  final String channelCode;
  final String label;
  final int feeIdr;

  const TopupMethodOption({
    required this.paymentType,
    required this.channelCode,
    required this.label,
    required this.feeIdr,
  });

  factory TopupMethodOption.fromJson(Map<String, dynamic> json) {
    return TopupMethodOption(
      paymentType: (json['payment_type'] ?? 'va').toString(),
      channelCode: (json['channel_code'] ?? '').toString(),
      label: (json['label'] ?? json['channel_code'] ?? '').toString(),
      feeIdr: _asInt(json['fee_idr']),
    );
  }
}

class TopupMethodsBundle {
  final String mode;
  final String activeProvider;
  final bool isSimulated;
  final int minAmountIdr;
  final int maxAmountIdr;
  final List<TopupMethodOption> methods;

  const TopupMethodsBundle({
    required this.mode,
    required this.activeProvider,
    required this.isSimulated,
    required this.minAmountIdr,
    required this.maxAmountIdr,
    required this.methods,
  });

  factory TopupMethodsBundle.fromJson(Map<String, dynamic> json) {
    final list = (json['methods'] as List? ?? [])
        .whereType<Map>()
        .map((m) => TopupMethodOption.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return TopupMethodsBundle(
      mode: (json['mode'] ?? 'sandbox').toString(),
      activeProvider: (json['active_provider'] ?? 'mock').toString(),
      isSimulated: json['is_simulated'] == true,
      minAmountIdr: _asInt(json['min_amount_idr'], fallback: 10000),
      maxAmountIdr: _asInt(json['max_amount_idr'], fallback: 10000000),
      methods: list,
    );
  }
}

class TopupTransactionV1 {
  final int id;
  final String reference;
  final String provider;
  final String mode;
  final bool isSimulated;
  final String paymentType;
  final String channelCode;
  final int amount;
  final int fee;
  final int netAmount;
  final String status;
  final String? providerReference;
  final String? vaNumber;
  final String? qrString;
  final String? paymentUrl;
  final List<String> instructions;
  final DateTime? expiredAt;
  final DateTime? paidAt;
  final DateTime? settledAt;
  final String? failureReason;
  final DateTime? createdAt;

  const TopupTransactionV1({
    required this.id,
    required this.reference,
    required this.provider,
    required this.mode,
    required this.isSimulated,
    required this.paymentType,
    required this.channelCode,
    required this.amount,
    required this.fee,
    required this.netAmount,
    required this.status,
    this.providerReference,
    this.vaNumber,
    this.qrString,
    this.paymentUrl,
    required this.instructions,
    this.expiredAt,
    this.paidAt,
    this.settledAt,
    this.failureReason,
    this.createdAt,
  });

  bool get isSettled => status == 'settled' || status == 'paid';

  factory TopupTransactionV1.fromJson(Map<String, dynamic> json) {
    return TopupTransactionV1(
      id: _asInt(json['id']),
      reference: (json['reference'] ?? '').toString(),
      provider: (json['provider'] ?? 'mock').toString(),
      mode: (json['mode'] ?? 'sandbox').toString(),
      isSimulated: json['is_simulated'] == true,
      paymentType: (json['payment_type'] ?? 'va').toString(),
      channelCode: (json['channel_code'] ?? '').toString(),
      amount: _asInt(json['amount']),
      fee: _asInt(json['fee']),
      netAmount: _asInt(json['net_amount']),
      status: (json['status'] ?? 'pending').toString(),
      providerReference: json['provider_reference']?.toString(),
      vaNumber: json['va_number']?.toString(),
      qrString: json['qr_string']?.toString(),
      paymentUrl: json['payment_url']?.toString(),
      instructions: (json['instructions'] as List? ?? []).map((e) => e.toString()).toList(),
      expiredAt: _parseDate(json['expired_at']),
      paidAt: _parseDate(json['paid_at']),
      settledAt: _parseDate(json['settled_at']),
      failureReason: json['failure_reason']?.toString(),
      createdAt: _parseDate(json['created_at']),
    );
  }
}

class PayoutDestinationV1 {
  final int id;
  final String ownerType;
  final String destinationType;
  final String channelCode;
  final String channelName;
  final String accountNumberMasked;
  final String accountHolderName;
  final bool isVerified;
  final String verificationStatus;
  final bool isDefault;
  final bool isActive;

  const PayoutDestinationV1({
    required this.id,
    required this.ownerType,
    required this.destinationType,
    required this.channelCode,
    required this.channelName,
    required this.accountNumberMasked,
    required this.accountHolderName,
    required this.isVerified,
    required this.verificationStatus,
    required this.isDefault,
    required this.isActive,
  });

  factory PayoutDestinationV1.fromJson(Map<String, dynamic> json) {
    return PayoutDestinationV1(
      id: _asInt(json['id']),
      ownerType: (json['owner_type'] ?? 'customer').toString(),
      destinationType: (json['destination_type'] ?? 'bank').toString(),
      channelCode: (json['channel_code'] ?? '').toString(),
      channelName: (json['channel_name'] ?? '').toString(),
      accountNumberMasked: (json['account_number_masked'] ?? '').toString(),
      accountHolderName: (json['account_holder_name'] ?? '').toString(),
      isVerified: json['is_verified'] == true,
      verificationStatus: (json['verification_status'] ?? 'verified').toString(),
      isDefault: json['is_default'] == true,
      isActive: json['is_active'] != false,
    );
  }
}

class PayoutTransactionV1 {
  final int id;
  final String reference;
  final String ownerType;
  final String payoutType;
  final String provider;
  final String mode;
  final bool isSimulated;
  final String channelCode;
  final String accountNumberMasked;
  final String accountHolderName;
  final int amount;
  final int fee;
  final int netAmount;
  final String status;
  final String? providerReference;
  final String? failureCode;
  final String? failureReason;
  final List<Map<String, dynamic>> statusHistory;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final DateTime? createdAt;

  const PayoutTransactionV1({
    required this.id,
    required this.reference,
    required this.ownerType,
    required this.payoutType,
    required this.provider,
    required this.mode,
    required this.isSimulated,
    required this.channelCode,
    required this.accountNumberMasked,
    required this.accountHolderName,
    required this.amount,
    required this.fee,
    required this.netAmount,
    required this.status,
    this.providerReference,
    this.failureCode,
    this.failureReason,
    required this.statusHistory,
    this.scheduledAt,
    this.completedAt,
    this.failedAt,
    this.createdAt,
  });

  factory PayoutTransactionV1.fromJson(Map<String, dynamic> json) {
    return PayoutTransactionV1(
      id: _asInt(json['id']),
      reference: (json['reference'] ?? '').toString(),
      ownerType: (json['owner_type'] ?? 'courier').toString(),
      payoutType: (json['payout_type'] ?? 'courier_auto_payout').toString(),
      provider: (json['provider'] ?? 'mock').toString(),
      mode: (json['mode'] ?? 'sandbox').toString(),
      isSimulated: json['is_simulated'] == true,
      channelCode: (json['channel_code'] ?? '').toString(),
      accountNumberMasked: (json['account_number_masked'] ?? '').toString(),
      accountHolderName: (json['account_holder_name'] ?? '').toString(),
      amount: _asInt(json['amount']),
      fee: _asInt(json['fee']),
      netAmount: _asInt(json['net_amount']),
      status: (json['status'] ?? 'pending').toString(),
      providerReference: json['provider_reference']?.toString(),
      failureCode: json['failure_code']?.toString(),
      failureReason: json['failure_reason']?.toString(),
      statusHistory: (json['status_history'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      scheduledAt: _parseDate(json['scheduled_at']),
      completedAt: _parseDate(json['completed_at']),
      failedAt: _parseDate(json['failed_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }
}

class EligibleRefundShipment {
  final int id;
  final String shipmentNumber;
  final String status;
  final int totalCost;

  const EligibleRefundShipment({
    required this.id,
    required this.shipmentNumber,
    required this.status,
    required this.totalCost,
  });

  factory EligibleRefundShipment.fromJson(Map<String, dynamic> json) {
    return EligibleRefundShipment(
      id: _asInt(json['id']),
      shipmentNumber: (json['shipment_number'] ?? '#${json['id']}').toString(),
      status: (json['status'] ?? '').toString(),
      totalCost: _asInt(json['total_cost']),
    );
  }
}

class RefundTransactionV1 {
  final int id;
  final String reference;
  final int? shipmentId;
  final int amount;
  final String reason;
  final String status;
  final String refundMethod;
  final String mode;
  final String? reviewNotes;
  final DateTime? processedAt;
  final DateTime? createdAt;

  const RefundTransactionV1({
    required this.id,
    required this.reference,
    this.shipmentId,
    required this.amount,
    required this.reason,
    required this.status,
    required this.refundMethod,
    required this.mode,
    this.reviewNotes,
    this.processedAt,
    this.createdAt,
  });

  factory RefundTransactionV1.fromJson(Map<String, dynamic> json) {
    return RefundTransactionV1(
      id: _asInt(json['id']),
      reference: (json['reference'] ?? '').toString(),
      shipmentId: json['shipment_id'] != null ? _asInt(json['shipment_id']) : null,
      amount: _asInt(json['amount']),
      reason: (json['reason'] ?? '').toString(),
      status: (json['status'] ?? 'requested').toString(),
      refundMethod: (json['refund_method'] ?? 'wallet_credit').toString(),
      mode: (json['mode'] ?? 'sandbox').toString(),
      reviewNotes: json['review_notes']?.toString(),
      processedAt: _parseDate(json['processed_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }
}

class CourierEarningsSummaryV1 {
  final int pendingEarnings;
  final int availableEarnings;
  final int reservedEarnings;
  final int paidEarnings;
  final int totalGrossEarnings;
  final int totalCommissionDeducted;
  final double commissionRatePercent;
  final int settlementWaitingMinutes;

  const CourierEarningsSummaryV1({
    required this.pendingEarnings,
    required this.availableEarnings,
    required this.reservedEarnings,
    required this.paidEarnings,
    required this.totalGrossEarnings,
    required this.totalCommissionDeducted,
    required this.commissionRatePercent,
    required this.settlementWaitingMinutes,
  });

  factory CourierEarningsSummaryV1.fromJson(Map<String, dynamic> json) {
    return CourierEarningsSummaryV1(
      pendingEarnings: _asInt(json['pending_earnings']),
      availableEarnings: _asInt(json['available_earnings']),
      reservedEarnings: _asInt(json['reserved_earnings']),
      paidEarnings: _asInt(json['paid_earnings']),
      totalGrossEarnings: _asInt(json['total_gross_earnings']),
      totalCommissionDeducted: _asInt(json['total_commission_deducted']),
      commissionRatePercent: (json['commission_rate_percent'] as num?)?.toDouble() ?? 10.0,
      settlementWaitingMinutes: _asInt(json['settlement_waiting_minutes'], fallback: 1440),
    );
  }
}

class CourierEarningV1 {
  final int id;
  final String reference;
  final int orderId;
  final int grossAmount;
  final double commissionRate;
  final int commissionAmount;
  final int netAmount;
  final String status;
  final String mode;
  final DateTime? earnedAt;
  final DateTime? availableAt;
  final DateTime? releasedAt;
  final DateTime? paidAt;

  const CourierEarningV1({
    required this.id,
    required this.reference,
    required this.orderId,
    required this.grossAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.netAmount,
    required this.status,
    required this.mode,
    this.earnedAt,
    this.availableAt,
    this.releasedAt,
    this.paidAt,
  });

  factory CourierEarningV1.fromJson(Map<String, dynamic> json) {
    return CourierEarningV1(
      id: _asInt(json['id']),
      reference: (json['reference'] ?? '').toString(),
      orderId: _asInt(json['order_id']),
      grossAmount: _asInt(json['gross_amount']),
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 10.0,
      commissionAmount: _asInt(json['commission_amount']),
      netAmount: _asInt(json['net_amount']),
      status: (json['status'] ?? 'pending').toString(),
      mode: (json['mode'] ?? 'sandbox').toString(),
      earnedAt: _parseDate(json['earned_at']),
      availableAt: _parseDate(json['available_at']),
      releasedAt: _parseDate(json['released_at']),
      paidAt: _parseDate(json['paid_at']),
    );
  }
}

class CourierWalletV1Summary {
  final int walletId;
  final int courierId;
  final String status;
  final bool isFrozen;
  final String? freezeReason;
  final int availableBalance;
  final int pendingBalance;
  final int reservedBalance;
  final String mode;
  final bool isSandboxOrDemo;
  final String activePayoutProvider;
  final bool autoPayoutEnabled;
  final int minPayoutIdr;
  final int feeIdr;
  final String scheduleCron;
  final bool eligibleForNextAutoPayout;
  final CourierEarningsSummaryV1 earningsSummary;
  final PayoutDestinationV1? defaultDestination;

  const CourierWalletV1Summary({
    required this.walletId,
    required this.courierId,
    required this.status,
    required this.isFrozen,
    this.freezeReason,
    required this.availableBalance,
    required this.pendingBalance,
    required this.reservedBalance,
    required this.mode,
    required this.isSandboxOrDemo,
    required this.activePayoutProvider,
    required this.autoPayoutEnabled,
    required this.minPayoutIdr,
    required this.feeIdr,
    required this.scheduleCron,
    required this.eligibleForNextAutoPayout,
    required this.earningsSummary,
    this.defaultDestination,
  });

  factory CourierWalletV1Summary.fromJson(Map<String, dynamic> json) {
    final policy = (json['payout_policy'] as Map?)?.cast<String, dynamic>() ?? {};
    final earnings = (json['earnings_summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final dest = json['default_destination'] is Map
        ? PayoutDestinationV1.fromJson(Map<String, dynamic>.from(json['default_destination'] as Map))
        : null;

    return CourierWalletV1Summary(
      walletId: _asInt(json['wallet_id']),
      courierId: _asInt(json['courier_id']),
      status: (json['status'] ?? 'active').toString(),
      isFrozen: json['is_frozen'] == true,
      freezeReason: json['freeze_reason']?.toString(),
      availableBalance: _asInt(json['available_balance']),
      pendingBalance: _asInt(json['pending_balance']),
      reservedBalance: _asInt(json['reserved_balance']),
      mode: (json['mode'] ?? 'sandbox').toString(),
      isSandboxOrDemo: json['is_sandbox_or_demo'] != false,
      activePayoutProvider: (json['active_payout_provider'] ?? 'mock').toString(),
      autoPayoutEnabled: policy['auto_payout_enabled'] != false,
      minPayoutIdr: _asInt(policy['min_payout_idr'], fallback: 20000),
      feeIdr: _asInt(policy['fee_idr']),
      scheduleCron: (policy['schedule_cron'] ?? '0 * * * *').toString(),
      eligibleForNextAutoPayout: policy['eligible_for_next_auto_payout'] == true,
      earningsSummary: CourierEarningsSummaryV1.fromJson(earnings),
      defaultDestination: dest,
    );
  }
}

class CourierAutoPayoutStatusV1 {
  final bool autoPayoutEnabled;
  final bool eligibleNow;
  final int availableBalance;
  final int reservedBalance;
  final int minPayoutIdr;
  final String scheduleCron;
  final PayoutDestinationV1? defaultDestination;
  final List<String> missingRequirements;

  const CourierAutoPayoutStatusV1({
    required this.autoPayoutEnabled,
    required this.eligibleNow,
    required this.availableBalance,
    required this.reservedBalance,
    required this.minPayoutIdr,
    required this.scheduleCron,
    this.defaultDestination,
    required this.missingRequirements,
  });

  factory CourierAutoPayoutStatusV1.fromJson(Map<String, dynamic> json) {
    return CourierAutoPayoutStatusV1(
      autoPayoutEnabled: json['auto_payout_enabled'] != false,
      eligibleNow: json['eligible_now'] == true,
      availableBalance: _asInt(json['available_balance']),
      reservedBalance: _asInt(json['reserved_balance']),
      minPayoutIdr: _asInt(json['min_payout_idr'], fallback: 20000),
      scheduleCron: (json['schedule_cron'] ?? '0 * * * *').toString(),
      defaultDestination: json['default_destination'] is Map
          ? PayoutDestinationV1.fromJson(Map<String, dynamic>.from(json['default_destination'] as Map))
          : null,
      missingRequirements: (json['missing_requirements'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class CourierPayoutNotificationV1 {
  final String id;
  final int payoutId;
  final String reference;
  final String status;
  final String title;
  final String message;
  final String mode;
  final DateTime? createdAt;

  const CourierPayoutNotificationV1({
    required this.id,
    required this.payoutId,
    required this.reference,
    required this.status,
    required this.title,
    required this.message,
    required this.mode,
    this.createdAt,
  });

  factory CourierPayoutNotificationV1.fromJson(Map<String, dynamic> json) {
    return CourierPayoutNotificationV1(
      id: (json['id'] ?? '').toString(),
      payoutId: _asInt(json['payout_id']),
      reference: (json['reference'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      mode: (json['mode'] ?? 'sandbox').toString(),
      createdAt: _parseDate(json['created_at']),
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
  return fallback;
}

DateTime? _parseDate(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
