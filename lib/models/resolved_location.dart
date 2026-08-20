class ResolvedLocation {
  const ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.district,
  });

  final double latitude;
  final double longitude;
  final String city;
  final String district;
}
