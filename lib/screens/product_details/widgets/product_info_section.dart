import 'package:flutter/material.dart';

class ProductInfoSection extends StatelessWidget {
  final bool isLoadingDetails;
  final String? description;
  final String? specifications;
  final String? detailsError;

  const ProductInfoSection({
    super.key,
    required this.isLoadingDetails,
    this.description,
    this.specifications,
    this.detailsError,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasDescription = description != null && description!.isNotEmpty;
    final bool hasSpecs = specifications != null && specifications!.isNotEmpty;
    final bool hasContent = hasDescription || hasSpecs;

    if (isLoadingDetails) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (!hasContent) {
      if (detailsError != null) {
        return const SizedBox.shrink();
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Text(
            'Geen omschrijving of specificaties gevonden.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasDescription) _DescriptionCard(description: description!),
        if (hasDescription && hasSpecs) const SizedBox(height: 16),
        if (hasSpecs) _SpecificationsCard(specifications: specifications!),
      ],
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  final String description;
  const _DescriptionCard({required this.description});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Omschrijving',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            description,
            style: textTheme.bodyLarge?.copyWith(
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecificationsCard extends StatelessWidget {
  final String specifications;
  const _SpecificationsCard({required this.specifications});

  List<MapEntry<String, String>> _parseSpecifications(String specs) {
    return specs
        .split('\n')
        .where((line) => line.contains(':') && line.trim().isNotEmpty)
        .map((line) {
      final parts = line.split(':');
      final key = parts.first.trim();
      final value = parts.sublist(1).join(':').trim();
      return MapEntry(key, value);
    }).toList();
  }

  Map<String, List<MapEntry<String, String>>> _groupSpecifications(
      List<MapEntry<String, String>> allSpecs) {
    final Map<String, List<String>> groupKeys = {
      'Product': ['Productnummer', 'EAN', 'Merk'],
      'Afmetingen & Gewicht': [
        'Gewicht product',
        'Hoogte product',
        'Lengte product',
        'Breedte product',
        'Afmetingen',
        'Oppervlakte'
      ],
      'Algemeen': [
        'Kleurfamilie',
        'Lijn',
        'Aantal stuks per verpakking',
        'Type',
        'Materiaal (detail)',
        'Materiaal',
        'Kleur',
        'Gebruik'
      ],
      'Afwerking': ['Afwerking', 'FSC-keurmerk', 'PEFC Keurmerk'],
      'Technische kenmerken': ['Type verbinding'],
    };

    final Map<String, List<MapEntry<String, String>>> grouped = {};
    final List<MapEntry<String, String>> remainingSpecs = List.from(allSpecs);

    groupKeys.forEach((groupTitle, keys) {
      final List<MapEntry<String, String>> groupSpecs = [];
      for (var key in keys) {
        final spec = remainingSpecs
            .firstWhere((s) => s.key == key, orElse: () => const MapEntry('', ''));
        if (spec.key.isNotEmpty) {
          groupSpecs.add(spec);
          remainingSpecs.remove(spec);
        }
      }
      if (groupSpecs.isNotEmpty) {
        grouped[groupTitle] = groupSpecs;
      }
    });

    if (remainingSpecs.isNotEmpty) {
      grouped['Overig'] = remainingSpecs;
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final allSpecs = _parseSpecifications(specifications);
    final groupedSpecs = _groupSpecifications(allSpecs);

    if (groupedSpecs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  color: colorScheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Specificaties',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: groupedSpecs.length,
            itemBuilder: (context, index) {
              final groupTitle = groupedSpecs.keys.elementAt(index);
              final specsInGroup = groupedSpecs.values.elementAt(index);
              return _SpecGroup(
                title: groupTitle,
                specs: specsInGroup,
              );
            },
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _SpecGroup extends StatelessWidget {
  final String title;
  final List<MapEntry<String, String>> specs;

  const _SpecGroup({required this.title, required this.specs});

  IconData _getIconForGroup(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('afmeting')) return Icons.straighten_outlined;
    if (lower.contains('product')) return Icons.inventory_2_outlined;
    if (lower.contains('algemeen')) return Icons.palette_outlined;
    if (lower.contains('afwerking')) return Icons.build_outlined;
    if (lower.contains('technische')) return Icons.settings_outlined;
    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_getIconForGroup(title),
                size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              title,
              style: textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...specs.map((spec) => _SpecRow(label: spec.key, value: spec.value)),
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;

  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style:
                  textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}