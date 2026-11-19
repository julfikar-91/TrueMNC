// lib/data/models/field_value_wrapper.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'field_value_wrapper.freezed.dart';
part 'field_value_wrapper.g.dart';

/// Provenance-tracked field value wrapper { value, provenance, evidence, confidence }.
/// Ensures AI never sets data without provenance tracking and confidence scoring.
@Freezed(genericArgumentFactories: true)
class FieldValueWrapper<T> with _$FieldValueWrapper<T> {
  const FieldValueWrapper._();

  const factory FieldValueWrapper({
    T? value,
    @JsonKey(unknownEnumValue: Provenance.missing)
    @Default(Provenance.missing)
    Provenance provenance,
    String? evidence,
    double? confidence,
  }) = _FieldValueWrapper<T>;

  factory FieldValueWrapper.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$FieldValueWrapperFromJson(json, fromJsonT);

  Map<String, dynamic> toFirestore(Object? Function(T value) toJsonT) =>
      toJson(toJsonT);
}
