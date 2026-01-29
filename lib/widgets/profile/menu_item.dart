import 'package:flutter/material.dart';

class MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;

  const MenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.iconColor,
    this.textColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor ?? Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 22,
            color: iconColor ?? Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor ?? Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        trailing: trailing ??
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).hintColor,
            ),
        onTap: onTap,
      ),
    );
  }
}
