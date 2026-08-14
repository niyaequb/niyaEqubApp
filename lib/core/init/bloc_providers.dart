import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/features/auth/state/auth_bloc.dart';
import 'package:provider/single_child_widget.dart';

import 'injections.dart';

import 'package:niya_equb/features/member/packages/state/equb_detail_bloc.dart';

List<SingleChildWidget> providers() {
  return [
    BlocProvider<AuthBloc>(create: (context) => sl()),
    BlocProvider<EqubDetailBloc>(create: (context) => sl()),
  ];
}
