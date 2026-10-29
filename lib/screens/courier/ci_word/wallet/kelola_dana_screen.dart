import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dompet_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dana_linking_screen.dart';

/// Kelola OVO Screen.
class KelolaDanaScreen extends StatefulWidget {
  const KelolaDanaScreen({super.key});

  @override
  State<KelolaDanaScreen> createState() => _KelolaDanaScreenState();
}

// Backward compatibility alias
typedef KelolaOvoScreen = KelolaDanaScreen;

class _KelolaDanaScreenState extends State<KelolaDanaScreen> {
  OvoConnection? _ovoConnection;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOvoStatus();
  }

  Future<void> _loadOvoStatus() async {
    setState(() => _isLoading = true);

    final result = await WalletService.getOvoStatus();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true && result['data'] != null) {
          _ovoConnection = OvoConnection.fromJson(result['data']);
        } else {
          _ovoConnection = OvoConnection(
            status: OvoConnectionStatus.notConnected,
          );
        }
      });
    }
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Koneksi OVO?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Anda tidak dapat melakukan penarikan sampai akun OVO terhubung kembali.',
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
          ElevatedButton(
            onPressed: _disconnectOvo,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus Koneksi'),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectOvo() async {
    Navigator.pop(context); // Close dialog

    setState(() => _isLoading = true);

    final result = await WalletService.disconnectOvo();

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Koneksi OVO berhasil dihapus'),
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
            content: Text(result['message'] ?? 'Gagal menghapus koneksi OVO'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                          _buildOvoInfoCard(),
                          const SizedBox(height: 16),
                          _buildConnectionStatusCard(),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
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
      color: Colors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Color(0xFF191B23)),
          ),
          const Expanded(
            child: Text(
              'Kelola OVO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191B23),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildOvoInfoCard() {
    final isConnected = _ovoConnection?.isConnected ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF4C3494),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'ovo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OVO Cash',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF191B23),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _ovoConnection?.maskedPhone ?? 'Belum terhubung',
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: Color(0xFF64748B),
                  ),
                ),
                if (isConnected && _ovoConnection?.accountName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'a.n ${_ovoConnection!.accountName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
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
    final isConnected = _ovoConnection?.isConnected ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.info_outline,
            color: isConnected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isConnected
                  ? 'Akun OVO aktif dan siap menerima pencairan saldo.'
                  : 'Akun OVO belum terhubung.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isConnected ? const Color(0xFF15803D) : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isConnected = _ovoConnection?.isConnected ?? false;

    return Column(
      children: [
        if (isConnected) ...[
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OvoLinkingScreen(
                      isUpdate: true,
                      initialName: _ovoConnection?.accountName,
                    ),
                  ),
                );
                if (updated == true) {
                  _loadOvoStatus();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C3494),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Ubah Nomor OVO', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _showDisconnectDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Hapus Koneksi OVO', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () async {
                final linked = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OvoLinkingScreen()),
                );
                if (linked == true) {
                  _loadOvoStatus();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C3494),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Hubungkan OVO', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ],
    );
  }
}
