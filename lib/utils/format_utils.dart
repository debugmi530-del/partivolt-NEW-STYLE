/// Formats a price number as a space-separated thousands string.
/// Example: 1234567.0 → "1 234 567"
String formatPrice(double price) {
  return price.toInt().toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]} ',
  );
}
