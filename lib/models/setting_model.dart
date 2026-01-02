import 'dart:convert';

class Setting {
  final String settingKey;
  final String settingValue;
  final String displayName;
  final String category;
  final String dataType;
  final int displayOrder;

  Setting({
    required this.settingKey,
    required this.settingValue,
    required this.displayName,
    required this.category,
    required this.dataType,
    required this.displayOrder,
  });

  factory Setting.fromJson(Map<String, dynamic> json) {
    return Setting(
      settingKey: json['setting_key'],
      settingValue: json['setting_value'],
      displayName: json['display_name'],
      category: json['category'],
      dataType: json['data_type'],
      displayOrder: json['display_order'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'setting_key': settingKey,
      'setting_value': settingValue,
      'display_name': displayName,
      'category': category,
      'data_type': dataType,
      'display_order': displayOrder,
    };
  }

  dynamic get parsedValue {
    switch (dataType) {
      case 'number':
        return double.tryParse(settingValue) ?? int.tryParse(settingValue) ?? 0;
      case 'boolean':
        return settingValue.toLowerCase() == 'true';
      case 'json':
        try {
          return json.decode(settingValue);
        } catch (e) {
          return settingValue;
        }
      case 'array':
        return settingValue.split(',');
      default:
        return settingValue;
    }
  }

  bool get isPaymentCategory => category == 'payment';
  bool get isContactCategory => category == 'contact';
  bool get isSystemCategory => category == 'system';
}
