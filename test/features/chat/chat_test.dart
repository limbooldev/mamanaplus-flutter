import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/features/chat/presentation/cubit/auth_cubit.dart';

class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);
  void increment() => emit(state + 1);
}

void main() {
  test('AuthState types', () {
    expect(AuthUnauthenticated(), isA<AuthState>());
    expect(AuthLoading(), isA<AuthState>());
  });

  blocTest<_CounterCubit, int>(
    'bloc_test smoke',
    build: _CounterCubit.new,
    act: (c) => c.increment(),
    expect: () => [1],
  );
}
