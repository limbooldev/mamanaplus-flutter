import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/chat_repository.dart';

class PublicGroup extends Equatable {
  const PublicGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.memberCount,
    required this.isMember,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String description;
  final int memberCount;
  final bool isMember;
  final DateTime createdAt;

  factory PublicGroup.fromJson(Map<String, dynamic> json) => PublicGroup(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
        isMember: json['is_member'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  PublicGroup copyWith({bool? isMember, int? memberCount}) => PublicGroup(
        id: id,
        title: title,
        description: description,
        memberCount: memberCount ?? this.memberCount,
        isMember: isMember ?? this.isMember,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, title, description, memberCount, isMember, createdAt];
}

class PublicGroupsState extends Equatable {
  const PublicGroupsState({
    this.items = const [],
    this.loading = false,
    this.error,
  });

  final List<PublicGroup> items;
  final bool loading;
  final String? error;

  PublicGroupsState copyWith({
    List<PublicGroup>? items,
    bool? loading,
    String? error,
  }) =>
      PublicGroupsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: error,
      );

  @override
  List<Object?> get props => [items, loading, error];
}

class PublicGroupsCubit extends Cubit<PublicGroupsState> {
  PublicGroupsCubit(this._repo) : super(const PublicGroupsState());

  final ChatRepository _repo;

  Future<void> refresh() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final raw = await _repo.listPublicGroups();
      final groups = raw.map(PublicGroup.fromJson).toList();
      emit(PublicGroupsState(items: groups, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> join(int groupId) async {
    await _repo.joinPublicGroup(groupId);
    final updated = state.items.map((g) {
      if (g.id == groupId) {
        return g.copyWith(isMember: true, memberCount: g.memberCount + 1);
      }
      return g;
    }).toList();
    emit(state.copyWith(items: updated));
  }

  Future<void> leave(int groupId) async {
    await _repo.leavePublicGroup(groupId);
    final updated = state.items.map((g) {
      if (g.id == groupId) {
        return g.copyWith(isMember: false, memberCount: (g.memberCount - 1).clamp(0, g.memberCount));
      }
      return g;
    }).toList();
    emit(state.copyWith(items: updated));
  }
}
