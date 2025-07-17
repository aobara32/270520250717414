// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env.dart';

// **************************************************************************
// EnviedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// generated_from: .env
final class _Env {
  static const List<int> _enviedkeyKEY = <int>[
    3767520783,
    4237385242,
    1172865660,
    3630886115,
    3410661236,
    1464289499,
  ];

  static const List<int> _envieddataKEY = <int>[
    3767520830,
    4237385256,
    1172865615,
    3630886103,
    3410661185,
    1464289517,
  ];

  static final String KEY = String.fromCharCodes(
    List<int>.generate(
      _envieddataKEY.length,
      (int i) => i,
      growable: false,
    ).map((int i) => _envieddataKEY[i] ^ _enviedkeyKEY[i]),
  );
}
