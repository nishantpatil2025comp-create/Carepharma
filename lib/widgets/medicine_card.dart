import 'package:flutter/material.dart';
import '../models/medicine.dart';

/// Renders a clinical medicine card/row according to the design system.
class MedicineCard extends StatelessWidget {
  const MedicineCard({
    super.key,
    required this.medicine,
    required this.onEdit,
    required this.onDelete,
    required this.onQuickRestock,
  });

  final Medicine medicine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onQuickRestock;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00685F);
    const tertiaryColor = Color(0xFF924628);
    const errorColor = Color(0xFFBA1A1A);

    // Stock Badge colors
    Color statusBg;
    Color statusFg;
    if (medicine.isOutOfStock) {
      statusBg = const Color(0xFFFFDAD6);
      statusFg = errorColor;
    } else if (medicine.isLowStock) {
      statusBg = const Color(0xFFFFDBCE);
      statusFg = tertiaryColor;
    } else {
      statusBg = primaryColor.withValues(alpha: 0.12);
      statusFg = primaryColor;
    }

    // Health progress bar percentage (relative to standard baseline of 100)
    final double stockPercentage = (medicine.stock / 100.0).clamp(0.0, 1.0);

    final stockSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            Text(
              '${medicine.stock} units',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: medicine.isOutOfStock
                    ? errorColor
                    : medicine.isLowStock
                        ? tertiaryColor
                        : const Color(0xFF191C1E),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                medicine.stockHealth,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusFg,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: stockPercentage,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(statusFg),
            minHeight: 4,
          ),
        ),
      ],
    );

    final expirySection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expiry',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: Color(0xFF6D7A77)),
        ),
        Text(
          medicine.expiryDate,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF191C1E),
          ),
        ),
      ],
    );

    final actionsSection = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick Restock (+10)
        InkWell(
          onTap: onQuickRestock,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '+10',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Edit
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Edit Medicine',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          color: const Color(0xFF3D4947),
          onPressed: onEdit,
        ),
        // Delete
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          tooltip: 'Delete Medicine',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          color: errorColor,
          onPressed: onDelete,
        ),
      ],
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: medicine.isLowStock
          ? const Color(0xFFFFF8F6)
          : medicine.isOutOfStock
              ? const Color(0xFFFFF5F5)
              : Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 420;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Name, Type Badge, Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicine.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF191C1E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  medicine.type,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3D4947),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  medicine.manufacturer,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6D7A77),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      medicine.formattedPrice,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191C1E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 0.6),
                const SizedBox(height: 12),

                // Row 2: Stock Health Bar & Badge, Expiry, Action Buttons
                if (isCompact) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 3, child: stockSection),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: expirySection),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [actionsSection],
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 3, child: stockSection),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: expirySection),
                      const SizedBox(width: 8),
                      actionsSection,
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

