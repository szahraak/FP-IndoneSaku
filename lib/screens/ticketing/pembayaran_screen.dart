import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/tiket_pesanan_model.dart';
import '../../services/mock_ticketing_service.dart';
import 'rangkuman_pemesanan_screen.dart';

class _SavedCard {
  final String maskedNumber;
  final String holderName;
  final String expiry;

  const _SavedCard({
    required this.maskedNumber,
    required this.holderName,
    required this.expiry,
  });
}

class PembayaranScreen extends StatefulWidget {
  final TiketPesanan pesanan;

  const PembayaranScreen({super.key, required this.pesanan});

  @override
  State<PembayaranScreen> createState() => _PembayaranScreenState();
}

class _PembayaranScreenState extends State<PembayaranScreen> {
  static const Color _primaryColor = Color(0xFF4B88A2);

  MetodePembayaran _selected = MetodePembayaran.qris;
  String? _selectedWallet;
  String? _selectedBank;

  static const _wallets = ['Dana', 'OVO', 'GoPay', 'ShopeePay', 'LinkAja'];
  static const _banks = ['BCA', 'BNI', 'Bank Mandiri', 'BRI', 'CIMB Niaga', 'BSI'];

  _SavedCard? _selectedCard;
  final List<_SavedCard> _savedCards = [
    _SavedCard(maskedNumber: '**** **** **** 4242', holderName: 'FAUZAN WILLIS', expiry: '08/27'),
    _SavedCard(maskedNumber: '**** **** **** 1234', holderName: 'FAUZAN WILLIS', expiry: '03/26'),
  ];

  // countdown 7 minutes
  late Timer _timer;
  int _secondsLeft = 7 * 60;

  final _currencyFmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer.cancel();
        _showTimeExpiredDialog();
      }
    });
  }

  void _showTimeExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Column(
          children: [
            Icon(Icons.timer_off_outlined, size: 48, color: Color(0xFFE53935)),
            SizedBox(height: 12),
            Text(
              'Waktu Habis',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: const Text(
          'Batas waktu pembayaran telah habis. Silakan lakukan pemesanan ulang.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Kembali',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _showSelectionSheet({
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            ...options.map(
              (opt) => ListTile(
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                leading: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF1A1A6E).withValues(alpha: 0.08),
                  child: Text(
                    opt[0],
                    style: const TextStyle(
                      color: Color(0xFF1A1A6E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  opt,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing: selected == opt
                    ? const Icon(Icons.check_circle,
                        color: Color(0xFF1A1A6E))
                    : Icon(Icons.radio_button_unchecked,
                        color: Colors.white),
                onTap: () {
                  onSelect(opt);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCardSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih Kartu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              if (_savedCards.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Belum ada kartu tersimpan',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                )
              else
                ..._savedCards.map(
                  (card) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A6E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.credit_card,
                        color: Color(0xFF1A1A6E),
                        size: 22,
                      ),
                    ),
                    title: Text(
                      card.maskedNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${card.holderName} • ${card.expiry}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    trailing: _selectedCard?.maskedNumber == card.maskedNumber
                        ? const Icon(Icons.check_circle, color: Color(0xFF1A1A6E))
                        : Icon(Icons.radio_button_unchecked, color: Colors.grey[400]),
                    onTap: () {
                      setState(() => _selectedCard = card);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add, color: Color(0xFF1A1A6E)),
                  label: const Text(
                    'Tambah Kartu Baru',
                    style: TextStyle(
                      color: Color(0xFF1A1A6E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1A1A6E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showAddCardSheet(onAdded: (card) {
                      setState(() {
                        _savedCards.add(card);
                        _selectedCard = card;
                      });
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCardSheet({required ValueChanged<_SavedCard> onAdded}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (ctx) => _AddCardSheet(onAdded: onAdded),
    );
  }

  String get _timerText {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onRangkuman() {
    final namaAkun = switch (_selected) {
      MetodePembayaran.dompetDigital => _selectedWallet ?? _selected.label,
      MetodePembayaran.transferBank => _selectedBank ?? _selected.label,
      MetodePembayaran.kartuKredit => _selectedCard?.maskedNumber ?? _selected.label,
      _ => _selected.label,
    };
    final updated = MockTicketingService.konfirmasiPembayaran(
      pesanan: widget.pesanan,
      metode: _selected,
      namaAkun: namaAkun,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RangkumanPemesananScreen(pesanan: updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pesanan = widget.pesanan;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pembayaran',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Countdown timer ───────────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 10),
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        _timerText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Jenis tiket summary ───────────────────────────
                  ...pesanan.items.map((item) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.namaJenisTiket,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                '${item.jumlah} x Rp ${_currencyFmt.format(item.hargaSatuan)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      )),
                  
                  const SizedBox(height: 8),
  
                  // ── Total Pembayaran ─────────────────────────────
                  const Text(
                    'Total Pembayaran',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${pesanan.totalJumlah} Item(s)',
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      Text(
                        _currencyFmt.format(pesanan.totalHarga),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Metode Pembayaran ─────────────────────────────
                  const Text(
                    'Metode Pembayaran',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...MetodePembayaran.values.map(
                    (metode) => _PaymentMethodTile(
                      metode: metode,
                      isSelected: _selected == metode,
                      subSelection: metode == MetodePembayaran.dompetDigital
                          ? _selectedWallet
                          : metode == MetodePembayaran.transferBank
                              ? _selectedBank
                              : metode == MetodePembayaran.kartuKredit
                                  ? _selectedCard?.maskedNumber
                                  : null,
                      onTap: () {
                        setState(() => _selected = metode);
                        if (metode == MetodePembayaran.dompetDigital) {
                          _showSelectionSheet(
                            title: 'Pilih Dompet Digital',
                            options: _wallets,
                            selected: _selectedWallet,
                            onSelect: (v) =>
                                setState(() => _selectedWallet = v),
                          );
                        } else if (metode == MetodePembayaran.transferBank) {
                          _showSelectionSheet(
                            title: 'Pilih Bank Tujuan',
                            options: _banks,
                            selected: _selectedBank,
                            onSelect: (v) =>
                                setState(() => _selectedBank = v),
                          );
                        } else if (metode == MetodePembayaran.kartuKredit) {
                          _showCardSheet();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom button ─────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _secondsLeft > 0 ? _onRangkuman : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Rangkuman Pemesanan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final MetodePembayaran metode;
  final bool isSelected;
  final VoidCallback onTap;
  final String? subSelection;

  static const Color _primaryColor = Color(0xFF4B88A2);

  const _PaymentMethodTile({
    required this.metode,
    required this.isSelected,
    required this.onTap,
    this.subSelection,
  });

  IconData get _icon {
    switch (metode) {
      case MetodePembayaran.qris:
        return Icons.qr_code_2;
      case MetodePembayaran.dompetDigital:
        return Icons.account_balance_wallet;
      case MetodePembayaran.transferBank:
        return Icons.account_balance;
      case MetodePembayaran.kartuKredit:
        return Icons.credit_card;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(

      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                size: 20,
                color: isSelected ? Colors.white : _primaryColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metode.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color:
                          isSelected ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    subSelection ?? metode.subLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white70
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: isSelected ? Colors.white : Colors.grey[400],
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCardSheet extends StatefulWidget {
  final ValueChanged<_SavedCard> onAdded;

  const _AddCardSheet({required this.onAdded});

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _cardNumberCtrl = TextEditingController();
  final _holderNameCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  bool _obscureCvv = true;

  static const Color _primaryColor = Color(0xFF4B88A2);

  @override
  void dispose() {
    _cardNumberCtrl.dispose();
    _holderNameCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final rawNumber = _cardNumberCtrl.text.replaceAll(' ', '');
    if (rawNumber.length < 16 ||
        _holderNameCtrl.text.trim().isEmpty ||
        _expiryCtrl.text.length < 5) {
      return;
    }
    final masked = '**** **** **** ${rawNumber.substring(rawNumber.length - 4)}';
    final card = _SavedCard(
      maskedNumber: masked,
      holderName: _holderNameCtrl.text.toUpperCase(),
      expiry: _expiryCtrl.text,
    );
    widget.onAdded(card);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tambah Kartu Baru',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cardNumberCtrl,
              keyboardType: TextInputType.number,
              maxLength: 19,
              decoration: InputDecoration(
                labelText: 'Nomor Kartu',
                hintText: 'XXXX XXXX XXXX XXXX',
                prefixIcon:
                    const Icon(Icons.credit_card, color: _primaryColor),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                counterText: '',
              ),
              onChanged: (v) {
                final digits = v.replaceAll(' ', '');
                final buf = StringBuffer();
                for (int i = 0; i < digits.length && i < 16; i++) {
                  if (i > 0 && i % 4 == 0) buf.write(' ');
                  buf.write(digits[i]);
                }
                final formatted = buf.toString();
                if (formatted != v) {
                  _cardNumberCtrl.value = TextEditingValue(
                    text: formatted,
                    selection:
                        TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _holderNameCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Nama Pemegang Kartu',
                prefixIcon: const Icon(Icons.person_outline,
                    color: _primaryColor),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiryCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    decoration: InputDecoration(
                      labelText: 'Kadaluarsa',
                      hintText: 'MM/YY',
                      prefixIcon: const Icon(Icons.calendar_today,
                          color: _primaryColor),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                    onChanged: (v) {
                      final digits = v.replaceAll('/', '');
                      if (digits.length >= 2) {
                        final formatted =
                            '${digits.substring(0, 2)}/${digits.substring(2)}';
                        if (formatted != v) {
                          _expiryCtrl.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                                offset: formatted.length),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatefulBuilder(
                    builder: (_, setRow) => TextField(
                      controller: _cvvCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: _obscureCvv,
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        hintText: 'XXX',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: _primaryColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCvv
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey[500],
                            size: 20,
                          ),
                          onPressed: () =>
                              setRow(() => _obscureCvv = !_obscureCvv),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        counterText: '',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Simpan Kartu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
