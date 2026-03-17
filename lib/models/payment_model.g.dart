// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaymentAdapter extends TypeAdapter<Payment> {
  @override
  final int typeId = 10;

  @override
  Payment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Payment(
      id: fields[0] as int,
      paymentType: fields[1] as String,
      amount: fields[2] as double,
      paymentMethod: fields[3] as String,
      accountHolderName: fields[4] as String?,
      status: fields[5] as String,
      createdAt: fields[6] as DateTime,
      categoryName: fields[7] as String,
      verifiedAt: fields[8] as DateTime?,
      rejectionReason: fields[9] as String?,
      categoryId: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Payment obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.paymentType)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.paymentMethod)
      ..writeByte(4)
      ..write(obj.accountHolderName)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.categoryName)
      ..writeByte(8)
      ..write(obj.verifiedAt)
      ..writeByte(9)
      ..write(obj.rejectionReason)
      ..writeByte(10)
      ..write(obj.categoryId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
