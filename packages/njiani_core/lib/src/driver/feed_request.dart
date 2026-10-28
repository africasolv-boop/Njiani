import 'package:flutter/foundation.dart';

import '../locale/nj_locale.dart';

/// One passenger waiting ahead of the driver, as the feed sees them.
///
/// Built from a row of `match_requests_for_session()`, which is the only way
/// a driver reads `ride_requests` at all — they hold no read policy on that
/// table, so there is no other shape this could arrive in.
///
/// Note what is **not** here: no passenger name, and no phone number. Those
/// are revealed to a driver only once a seat is claimed, and only for that
/// seat (ARCHITECTURE §8). A card in the feed is an offer, not a person's
/// details.
@immutable
class FeedRequest {
  const FeedRequest({
    required this.id,
    required this.pickupStage,
    required this.pickupStageSw,
    required this.destStage,
    required this.destStageSw,
    required this.offerPrice,
    required this.metresAhead,
    this.createdAt,
  });

  factory FeedRequest.fromRow(Map<String, dynamic> row) => FeedRequest(
        id: row['request_id'] as String,
        pickupStage: row['pickup_stage'] as String? ?? '',
        pickupStageSw: row['pickup_stage_sw'] as String? ?? '',
        destStage: row['dest_stage'] as String? ?? '',
        destStageSw: row['dest_stage_sw'] as String? ?? '',
        offerPrice: (row['offer_price'] as num?)?.toInt() ?? 0,
        metresAhead: (row['meters_ahead'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      );

  final String id;

  final String pickupStage;
  final String pickupStageSw;
  final String destStage;
  final String destStageSw;

  /// What the passenger offered, in whole shillings. Theirs to set.
  final int offerPrice;

  /// Distance **along the road**, not as the crow flies: "400 m ahead" has to
  /// mean 400 m of driving.
  final int metresAhead;

  final DateTime? createdAt;

  String pickupLabel(NjLocale locale) =>
      locale == NjLocale.sw ? pickupStageSw : pickupStage;

  String destLabel(NjLocale locale) =>
      locale == NjLocale.sw ? destStageSw : destStage;

  @override
  bool operator ==(Object other) =>
      other is FeedRequest &&
      other.id == id &&
      other.offerPrice == offerPrice &&
      other.metresAhead == metresAhead;

  @override
  int get hashCode => Object.hash(id, offerPrice, metresAhead);

  @override
  String toString() =>
      'FeedRequest($pickupStage → $destStage, $offerPrice, ${metresAhead}m)';
}
