import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api_config.dart';
import '../../../../core/dio_client.dart';
import '../../../../core/token_storage.dart';
import '../../data/chat_remote_datasource.dart';

String _extractErrorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['error'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
  }
  return e.toString();
}

sealed class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthAuthenticated extends AuthState {
  AuthAuthenticated(this.accessToken);
  final String accessToken;
  @override
  List<Object?> get props => [accessToken];
}

class AuthFailure extends AuthState {
  AuthFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required ApiConfig config,
    required TokenStorage tokens,
  })  : _config = config,
        _tokens = tokens,
        super(AuthInitial()) {
    notifier = ValueNotifier<AuthState>(state);
  }

  final ApiConfig _config;
  final TokenStorage _tokens;

  /// Drives [GoRouter] redirect refresh.
  late final ValueNotifier<AuthState> notifier;

  @override
  void onChange(Change<AuthState> change) {
    super.onChange(change);
    notifier.value = change.nextState;
  }

  Future<void> restore() async {
    emit(AuthLoading());
    try {
      final t = await _tokens.getAccessToken();
      if (t != null && t.isNotEmpty) {
        emit(AuthAuthenticated(t));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      final dio = createDio(config: _config, tokens: _tokens);
      final ds = ChatRemoteDataSource(dio);
      final data = await ds.login(email: email, password: password);
      final access = data['access_token'] as String;
      final refresh = data['refresh_token'] as String;
      await _tokens.saveTokens(access: access, refresh: refresh);
      emit(AuthAuthenticated(access));
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  Future<void> register(String email, String password, String displayName) async {
    emit(AuthLoading());
    try {
      final dio = createDio(config: _config, tokens: _tokens);
      final ds = ChatRemoteDataSource(dio);
      final data = await ds.register(email: email, password: password, displayName: displayName);
      final access = data['access_token'] as String;
      final refresh = data['refresh_token'] as String;
      await _tokens.saveTokens(access: access, refresh: refresh);
      emit(AuthAuthenticated(access));
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  Future<void> logout() async {
    await _tokens.clear();
    emit(AuthUnauthenticated());
  }
}
