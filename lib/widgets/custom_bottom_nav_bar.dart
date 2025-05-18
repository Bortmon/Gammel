import 'package:flutter/material.dart';

enum BottomNavTab { agenda, home, scanner }

class CustomBottomNavBar extends StatelessWidget {
  final BottomNavTab? currentTab;
  final Function(BottomNavTab) onTabSelected;

  const CustomBottomNavBar({
    super.key,
    this.currentTab,
    required this.onTabSelected,
  });

  Widget _buildNavItem(BuildContext context, {
    required IconData icon,
    required String label,
    required BottomNavTab tab,
    bool isSelected = false,
  }) {
    final ColorScheme clr = Theme.of(context).colorScheme;
    final Color iconColor = isSelected ? clr.primary : clr.onSurface.withAlpha((0.6 * 255).round());
    final Color labelColor = isSelected ? clr.primary : clr.onSurface.withAlpha((0.8 * 255).round());

    return Expanded(
      child: InkWell(
        onTap: () => onTabSelected(tab),
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: labelColor, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme clr = Theme.of(context).colorScheme;
    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: clr.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildNavItem(
            context,
            icon: Icons.calendar_month_outlined,
            label: 'Agenda',
            tab: BottomNavTab.agenda,
            isSelected: currentTab == BottomNavTab.agenda,
          ),
          _buildNavItem( 
            context,
            icon: Icons.home_outlined, 
            label: 'Home',             
            tab: BottomNavTab.home,   
            isSelected: currentTab == BottomNavTab.home,
          ),
          _buildNavItem(
            context,
            icon: Icons.qr_code_scanner_outlined,
            label: 'Scanner',
            tab: BottomNavTab.scanner,
            isSelected: currentTab == BottomNavTab.scanner,
          ),
        ],
      ),
    );
  }
}