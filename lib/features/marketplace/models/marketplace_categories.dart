class MarketplaceCategory {
  final String id;
  final String urduLabel;
  final String englishLabel;

  const MarketplaceCategory({
    required this.id,
    required this.urduLabel,
    required this.englishLabel,
  });

  String label(bool isUrdu) => isUrdu ? urduLabel : englishLabel;
}

const marketplaceCategories = [
  MarketplaceCategory(
    id: 'electronics',
    urduLabel: 'الیکٹرانکس',
    englishLabel: 'Electronics',
  ),
  MarketplaceCategory(id: 'home', urduLabel: 'گھر', englishLabel: 'Home'),
  MarketplaceCategory(
    id: 'fashion',
    urduLabel: 'کپڑے اور فیشن',
    englishLabel: 'Fashion',
  ),
  MarketplaceCategory(id: 'tools', urduLabel: 'اوزار', englishLabel: 'Tools'),
  MarketplaceCategory(
    id: 'vehicles',
    urduLabel: 'گاڑیاں',
    englishLabel: 'Vehicles',
  ),
  MarketplaceCategory(id: 'other', urduLabel: 'دیگر', englishLabel: 'Other'),
];
