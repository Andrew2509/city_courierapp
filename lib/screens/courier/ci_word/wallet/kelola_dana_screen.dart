import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dompet_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dana_linking_screen.dart';

/// Kelola DANA Screen.
/// PRD §33: Kelola DANA - view status, reconnect, disconnect.
/// PRD §35: Hubungkan Ulang flow.
/// PRD §34: Putuskan DANA with confirmation and processing check.
class KelolaDanaScreen extends StatefulWidget {
  const KelolaDanaScreen({super.key});

  @override
  State<KelolaDanaScreen> createState() => _KelolaDanaScreenState();
}

class _KelolaDanaScreenState extends State<KelolaDanaScreen> {
  DanaConnection? _danaConnection;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDanaStatus();
  }

  Future<void> _loadDanaStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await WalletService.getDanaStatus();

    if (!mounted) return;

    setState(() {
      _isLoading = false;

      if (result['success'] == true && result['data'] != null) {
        _danaConnection = DanaConnection.fromJson(
          (result['data'] as Map).cast<String, dynamic>(),
        );
      } else {
        // Tidak ada data → akun memang belum terhubung. Jangan menampilkan
        // data contoh.
        _danaConnection = DanaConnection(status: DanaConnectionStatus.notConnected);
        _error = result['message']?.toString();
      }
    });
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Putuskan DANA?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Anda tidak dapat melakukan penarikan sampai akun DANA terhubung kembali.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Batal',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ),
          TextButton(
            onPressed: _disconnectDana,
            child: const Text(
              'Putuskan',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectDana() async {
    Navigator.pop(context); // Close dialog

    setState(() => _isLoading = true);

    final result = await WalletService.disconnectDana();

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('DANA berhasil diputuskan'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DompetScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal memutuskan DANA'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// PRD §35: Hubungkan Ulang - replace DANA account.
  Future<void> _reconnectDana() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DanaLinkingScreen()),
    );

    if (mounted) {
      await _loadDanaStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryOrange),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildDanaInfoCard(),
                          const SizedBox(height: 16),
                          _buildConnectionStatusCard(),
                          const SizedBox(height: 24),
                          // PRD §35: Hubungkan Ulang button
                          _buildReconnectButton(),
                          const SizedBox(height: 12),
                          _buildDisconnectButton(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      color: AppColors.backgroundColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Color(0xFF191B23)),
          ),
          const Expanded(
            child: Text(
              'Kelola DANA',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191B23)),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildDanaInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF006A61).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet, color: Color(0xFF006A61), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DANA',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF191B23)),
                ),
                const SizedBox(height: 4),
                Text(
                  _danaConnection?.maskedPhone ?? 'Belum terhubung',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF64748B)),
                ),
                if ((_danaConnection?.accountName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'a.n ${_danaConnection!.accountName}',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    final isConnected = _danaConnection?.isConnected ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected
            ? const Color(0xFF22C55E).withOpacity(0.05)
            : const Color(0xFFEF4444).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF22C55E).withOpacity(0.3)
              : const Color(0xFFEF4444).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.error,
            color: isConnected ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status Koneksi',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  isConnected ? 'Terhubung' : 'Tidak Terhubung',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isConnected ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// PRD §35: Hubungkan Ulang - replace current DANA account.
  Widget _buildReconnectButton() {
    final isConnected = _danaConnection?.isConnected ?? false;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _reconnectDana,
        icon: Icon(isConnected ? Icons.link : Icons.add_link, color: AppColors.primaryOrange, size: 18),
        label: Text(
          isConnected ? 'Hubungkan Ulang' : 'Hubungkan DANA',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryOrange),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: AppColors.primaryOrange),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  /// PRD §34: Putuskan DANA with processing check.
  Widget _buildDisconnectButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _showDisconnectDialog,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Putuskan DANA',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red),
        ),
      ),
    );
  }
}
