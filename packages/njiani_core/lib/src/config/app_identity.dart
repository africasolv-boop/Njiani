/// Which of the two Njiani apps this binary is.
///
/// Both apps share [njiani_core], so shared widgets need a way to ask who they
/// are running inside. This is that way -- passed down from each app's
/// `main()`, never inferred.
enum NjianiApp {
  /// "Njiani" -- the passenger app. Bundle `tz.njiani.rider`.
  rider(
    label: 'Njiani',
    tagline: 'Rides going your way.',
    taglineSw: 'Usafiri unaoelekea njia yako.',
    bundleId: 'tz.njiani.rider',
  ),

  /// "Njiani Driver". Bundle `tz.njiani.driver`.
  driver(
    label: 'Njiani Driver',
    tagline: 'Fill your seats on the road you are already taking.',
    taglineSw: 'Jaza viti vyako kwenye barabara unayoitumia tayari.',
    bundleId: 'tz.njiani.driver',
  );

  const NjianiApp({
    required this.label,
    required this.tagline,
    required this.taglineSw,
    required this.bundleId,
  });

  /// Store-facing name.
  final String label;

  /// One-line description, English.
  final String tagline;

  /// One-line description, Kiswahili.
  final String taglineSw;

  /// Android applicationId and iOS bundle identifier.
  final String bundleId;

  bool get isRider => this == NjianiApp.rider;
  bool get isDriver => this == NjianiApp.driver;
}
