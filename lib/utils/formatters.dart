/// Formate un montant en FCFA avec séparateur de milliers (espace), ex: "25 000 FCFA".
String formatCfa(num amount) {
  final str = amount.round().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(str[i]);
  }
  return '${buffer.toString()} FCFA';
}

String formatShortDate(DateTime date) {
  const mois = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
    'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
  ];
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${mois[date.month - 1]} • $h:$m';
}
