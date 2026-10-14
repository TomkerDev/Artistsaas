import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../features/store/data/store_admin_service.dart';
import '../features/store/domain/store_models.dart';

/// Boîtes de dialogue d'édition des documents publiés (événements, articles,
/// billets).
///
/// Chaque dialogue est **pré-rempli** avec les valeurs courantes et renvoie un
/// résultat typé à l'appelant, qui se charge du `update()` Firestore. Le
/// résultat est `null` si l'utilisateur annule.
///
/// L'extension [AdminEditApplier] regroupe les `update()` des trois
/// collections, afin que les écrans n'aient qu'à appeler une seule méthode
/// après confirmation.

/// Champs modifiés d'un concert, renvoyés par [EventEditDialog].
@immutable
class EventEditResult {
  const EventEditResult({
    required this.id,
    required this.title,
    required this.date,
    required this.dateLabel,
    required this.location,
    required this.priceStd,
    required this.priceVip,
    required this.mobileMoneyNumber,
    required this.totalSeats,
  });

  final String id;
  final String title;
  final DateTime date;
  final String dateLabel;
  final String location;
  final double priceStd;
  final double priceVip;
  final String mobileMoneyNumber;
  final int totalSeats;
}

/// Dialogue d'édition d'un concert, pré-rempli avec [event].
class EventEditDialog extends StatefulWidget {
  const EventEditDialog({required this.event, super.key});

  final ShowEvent event;

  @override
  State<EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends State<EventEditDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.event.title,
  );
  late final TextEditingController _location = TextEditingController(
    text: widget.event.location,
  );
  late final TextEditingController _std = TextEditingController(
    text: widget.event.priceStd.toStringAsFixed(0),
  );
  late final TextEditingController _vip = TextEditingController(
    text: widget.event.priceVip.toStringAsFixed(0),
  );
  late final TextEditingController _money = TextEditingController(
    text: widget.event.mobileMoneyNumber,
  );
  late final TextEditingController _seats = TextEditingController(
    text: '${widget.event.totalSeats}',
  );
  late final TextEditingController _date = TextEditingController(
    text: _isoDate(widget.event.date),
  );

  /// Date ISO `AAAA-MM-JJ` attendue par le formulaire.
  static String _isoDate(DateTime? date) {
    final DateTime? value = date;
    if (value == null) {
      return '';
    }
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _title,
      _location,
      _std,
      _vip,
      _money,
      _seats,
      _date,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) {
      return;
    }
    final DateTime? parsed = DateTime.tryParse(_date.text.trim());
    if (parsed == null) {
      return;
    }
    Navigator.of(context).pop(
      EventEditResult(
        id: widget.event.id,
        title: _title.text.trim(),
        date: parsed,
        dateLabel: _date.text.trim(),
        location: _location.text.trim(),
        priceStd: double.parse(_std.text.trim()),
        priceVip: double.parse(_vip.text.trim()),
        mobileMoneyNumber: _money.text.trim(),
        totalSeats: int.parse(_seats.text.trim()),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le concert'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Titre'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _date,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    helperText: 'Format ISO : 2026-07-18',
                  ),
                  validator: _dateValidator,
                ),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(labelText: 'Lieu'),
                  validator: _required,
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _std,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Prix standard',
                        ),
                        validator: _positiveNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _vip,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Prix VIP'),
                        validator: _positiveNumber,
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _money,
                  decoration: const InputDecoration(
                    labelText: 'Numéro Mobile Money',
                  ),
                  validator: _required,
                ),
                TextFormField(
                  controller: _seats,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de places',
                  ),
                  validator: _positiveNumber,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }

  static String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Champ obligatoire' : null;

  static String? _positiveNumber(String? value) {
    final double? parsed = double.tryParse((value ?? '').trim());
    if (parsed == null || parsed <= 0) {
      return 'Nombre positif attendu';
    }
    return null;
  }

  static String? _dateValidator(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'Champ obligatoire';
    }
    if (DateTime.tryParse(raw) == null) {
      return 'Format attendu : 2026-07-18';
    }
    return null;
  }
}


/// Champs modifiés d'un article, renvoyés par [MerchEditDialog].
@immutable
class MerchEditResult {
  const MerchEditResult({
    required this.id,
    required this.name,
    required this.description,
    required this.priceFcfa,
    required this.imageUrl,
    required this.sizes,
    required this.whatsappContact,
  });

  final String id;
  final String name;
  final String description;
  final double priceFcfa;
  final String imageUrl;
  final List<String> sizes;
  final String whatsappContact;
}

/// Dialogue d'édition d'un article, pré-rempli avec [product].
class MerchEditDialog extends StatefulWidget {
  const MerchEditDialog({required this.product, super.key});

  final MerchProduct product;

  @override
  State<MerchEditDialog> createState() => _MerchEditDialogState();
}

class _MerchEditDialogState extends State<MerchEditDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.product.name,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.product.description,
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.product.priceFcfa.toStringAsFixed(0),
  );
  late final TextEditingController _image = TextEditingController(
    text: widget.product.imageUrl,
  );
  late final TextEditingController _sizes = TextEditingController(
    text: widget.product.sizes.join(','),
  );
  late final TextEditingController _whatsapp = TextEditingController(
    text: widget.product.whatsappContact,
  );

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _description,
      _price,
      _image,
      _sizes,
      _whatsapp,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      MerchEditResult(
        id: widget.product.id,
        name: _name.text.trim(),
        description: _description.text.trim(),
        priceFcfa: double.parse(_price.text.trim()),
        imageUrl: _image.text.trim(),
        sizes: _sizes.text.split(','),
        whatsappContact: _whatsapp.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier l\'article'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    helperText: 'Facultatif',
                  ),
                ),
                TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Prix FCFA'),
                  validator: _positiveNumber,
                ),
                TextFormField(
                  controller: _image,
                  decoration: const InputDecoration(
                    labelText: 'URL image',
                    helperText: 'Facultatif — une icône est utilisée sinon',
                  ),
                  validator: _optionalUrl,
                ),
                TextFormField(
                  controller: _sizes,
                  decoration: const InputDecoration(
                    labelText: 'Tailles séparées par des virgules',
                  ),
                ),
                TextFormField(
                  controller: _whatsapp,
                  decoration: const InputDecoration(
                    labelText: 'Contact WhatsApp',
                  ),
                  validator: _required,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }

  static String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Champ obligatoire' : null;

  static String? _positiveNumber(String? value) {
    final double? parsed = double.tryParse((value ?? '').trim());
    if (parsed == null || parsed <= 0) {
      return 'Prix positif attendu';
    }
    return null;
  }

  static String? _optionalUrl(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    return RegExp(r'^https?://').hasMatch(raw)
        ? null
        : 'URL invalide (http:// ou https://)';
  }
}


/// Champs modifiés d'un billet, renvoyés par [TicketEditDialog].
@immutable
class TicketEditResult {
  const TicketEditResult({
    required this.id,
    required this.ticketType,
    required this.status,
  });

  final String id;
  final String ticketType;
  final String status;
}

/// Dialogue d'édition d'un billet (type et statut), pré-rempli avec [ticket].
class TicketEditDialog extends StatefulWidget {
  const TicketEditDialog({required this.ticket, super.key});

  final StoreTicket ticket;

  @override
  State<TicketEditDialog> createState() => _TicketEditDialogState();
}

class _TicketEditDialogState extends State<TicketEditDialog> {
  late String _type = widget.ticket.ticketType;
  late String _status = widget.ticket.status;

  void _submit() {
    Navigator.of(context).pop(
      TicketEditResult(id: widget.ticket.id, ticketType: _type, status: _status),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le billet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type de billet'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'standard',
                child: Text('Standard'),
              ),
              DropdownMenuItem<String>(value: 'vip', child: Text('VIP')),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _type = value);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Statut'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: StoreTicket.statusPending,
                child: Text('En attente'),
              ),
              DropdownMenuItem<String>(
                value: StoreTicket.statusConfirmed,
                child: Text('Confirmé'),
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _status = value);
              }
            },
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}

/// Applique le résultat d'un dialogue d'édition à Firestore.
///
/// Regroupe les `update()` des trois collections pour que les écrans n'aient
/// qu'à appeler une seule méthode après confirmation.
extension AdminEditApplier on StoreAdminService {
  /// Applique un [EventEditResult] (mis à jour du concert correspondant).
  Future<void> applyEventEdit(EventEditResult result) => updateEvent(
    id: result.id,
    title: result.title,
    date: result.date,
    dateLabel: result.dateLabel,
    location: result.location,
    priceStd: result.priceStd,
    priceVip: result.priceVip,
    mobileMoneyNumber: result.mobileMoneyNumber,
    totalSeats: result.totalSeats,
  );

  /// Applique un [MerchEditResult] (mis à jour de l'article correspondant).
  Future<void> applyMerchEdit(MerchEditResult result) => updateMerch(
    id: result.id,
    name: result.name,
    description: result.description,
    priceFcfa: result.priceFcfa,
    imageUrl: result.imageUrl,
    sizes: result.sizes,
    whatsappContact: result.whatsappContact,
  );

  /// Applique un [TicketEditResult] (type et statut du billet).
  Future<void> applyTicketEdit(TicketEditResult result) =>
      FirebaseFirestore.instance
          .collection('tickets')
          .doc(result.id)
          .update(<String, Object?>{
            'ticket_type': result.ticketType,
            'status': result.status,
          });
}

