import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive_ce.dart';

class FastingProtocol extends Equatable {
  const FastingProtocol({
    required this.id,
    required this.name,
    required this.fastingMinutes,
    required this.feedingMinutes,
    this.description,
  });

  final String id;
  final String name;
  final int fastingMinutes;
  final int feedingMinutes;
  final String? description;

  Duration get fastingDuration => Duration(minutes: fastingMinutes);
  Duration get feedingDuration => Duration(minutes: feedingMinutes);
  Duration get totalDuration => fastingDuration + feedingDuration;

  @override
  List<Object?> get props => [
        id,
        name,
        fastingMinutes,
        feedingMinutes,
        description,
      ];

  FastingProtocol copyWith({
    String? id,
    String? name,
    int? fastingMinutes,
    int? feedingMinutes,
    String? description,
  }) {
    return FastingProtocol(
      id: id ?? this.id,
      name: name ?? this.name,
      fastingMinutes: fastingMinutes ?? this.fastingMinutes,
      feedingMinutes: feedingMinutes ?? this.feedingMinutes,
      description: description ?? this.description,
    );
  }

  static const List<FastingProtocol> defaults = [
    FastingProtocol(
      id: '12_12',
      name: '12:12',
      fastingMinutes: 12 * 60,
      feedingMinutes: 12 * 60,
      description: 'Jejum de 12h e alimentação por 12h.',
    ),
    FastingProtocol(
      id: '16_8',
      name: '16:8',
      fastingMinutes: 16 * 60,
      feedingMinutes: 8 * 60,
      description: 'Jejum de 16h e alimentação por 8h.',
    ),
    FastingProtocol(
      id: '18_6',
      name: '18:6',
      fastingMinutes: 18 * 60,
      feedingMinutes: 6 * 60,
      description: 'Jejum de 18h e alimentação por 6h.',
    ),
    FastingProtocol(
      id: '20_4',
      name: '20:4',
      fastingMinutes: 20 * 60,
      feedingMinutes: 4 * 60,
      description: 'Jejum de 20h e alimentação por 4h.',
    ),
    FastingProtocol(
      id: '24_0',
      name: '24:0',
      fastingMinutes: 24 * 60,
      feedingMinutes: 0,
      description: 'Jejum de 24h com janela de alimentação zero.',
    ),
  ];
}

class FastingProtocolAdapter extends TypeAdapter<FastingProtocol> {
  static const int typeKey = 1;

  @override
  int get typeId => typeKey;

  @override
  FastingProtocol read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final fastingMinutes = reader.readInt();
    final feedingMinutes = reader.readInt();
    final description = reader.readString();

    return FastingProtocol(
      id: id,
      name: name,
      fastingMinutes: fastingMinutes,
      feedingMinutes: feedingMinutes,
      description: description.isEmpty ? null : description,
    );
  }

  @override
  void write(BinaryWriter writer, FastingProtocol obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeInt(obj.fastingMinutes)
      ..writeInt(obj.feedingMinutes)
      ..writeString(obj.description ?? '');
  }
}
