import 'package:flutter/material.dart';

class ProductInfoSection extends StatelessWidget
{
  final bool isLoadingDetails;
  final String? description;
  final String? specifications;
  final String? detailsError;

  const ProductInfoSection(
  {
    super.key,
    required this.isLoadingDetails,
    this.description,
    this.specifications,
    this.detailsError,
  });

  @override
  Widget build(BuildContext context)
  {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme clr = Theme.of(context).colorScheme;
    final bool hasDescription = description != null && description!.isNotEmpty;
    final bool hasSpecs = specifications != null &&
                          !specifications!.contains('niet gevonden') &&
                          !specifications!.contains('leeg') &&
                          specifications!.isNotEmpty;

    if (isLoadingDetails && !hasDescription && !hasSpecs)
    {
      return const Center(child: Padding( padding: EdgeInsets.symmetric(vertical: 40.0), child: CircularProgressIndicator()));
    }

    if (detailsError != null && !hasDescription && !hasSpecs && !isLoadingDetails)
    {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: clr.surfaceContainerLow, // Subtiel andere achtergrond
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
        [
          if(detailsError != null && (hasDescription || hasSpecs))
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text("Let op: $detailsError", style: TextStyle(color: Colors.orange[800], fontStyle: FontStyle.italic)),
            ),

          if (hasDescription) ...
          [
            Text('Omschrijving', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: textTheme.titleLarge?.color)),
            const SizedBox(height: 10),
            SelectableText(description!, style: textTheme.bodyLarge?.copyWith(height: 1.55, color: textTheme.bodyMedium?.color?.withOpacity(0.9))),
            SizedBox(height: (hasDescription && hasSpecs) ? 24 : 8),
          ],

          if (hasDescription && hasSpecs) ...
          [
            Divider(thickness: 0.5, color: clr.outlineVariant.withOpacity(0.5)),
            const SizedBox(height: 24),
          ],

          if (hasSpecs) ...
          [
            Text('Specificaties', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: textTheme.titleLarge?.color)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14.0), // Iets meer padding
              decoration: BoxDecoration(
                color: clr.surfaceContainerLowest, // Nog subtieler voor de specs box zelf
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: clr.outlineVariant.withOpacity(0.3), width: 0.7)
              ),
              child: SelectableText(
                specifications!,
                style: textTheme.bodyMedium?.copyWith(height: 1.6, fontFamily: 'monospace', color: textTheme.bodySmall?.color?.withOpacity(0.95)),
              )
            ),
             const SizedBox(height: 8),
          ],

          if (!hasDescription && !hasSpecs && !isLoadingDetails) ...
          [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('Geen omschrijving of specificaties gevonden.', style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[600]))
                ),
              )
          ]
        ],
      ),
    );
  }
}