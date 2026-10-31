// Changing the sign-in e-mail (Figma ACC-08..10): the form and the "check your e-mail" state.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/email_change.dart';
import '../../domain/repositories/email_change_repository.dart';

class EmailChangeState extends Equatable {
  const EmailChangeState({this.currentEmail, this.busy = false, this.sentTo, this.issue});

  /// null while loading (or if the server did not say).
  final String? currentEmail;
  final bool busy;

  /// Set once the link was sent: the screen shows "check your e-mail".
  final String? sentTo;
  final EmailChangeIssue? issue;

  bool get locked => issue?.kind == EmailChangeIssueKind.rateLimited;

  EmailChangeState copyWith({
    String? currentEmail,
    bool? busy,
    String? sentTo,
    bool clearSent = false,
    EmailChangeIssue? issue,
    bool clearIssue = false,
  }) =>
      EmailChangeState(
        currentEmail: currentEmail ?? this.currentEmail,
        busy: busy ?? this.busy,
        sentTo: clearSent ? null : (sentTo ?? this.sentTo),
        issue: clearIssue ? null : (issue ?? this.issue),
      );

  @override
  List<Object?> get props => [currentEmail, busy, sentTo, issue];
}

class EmailChangeCubit extends Cubit<EmailChangeState> {
  EmailChangeCubit(this._repository) : super(const EmailChangeState());

  final EmailChangeRepository _repository;

  Future<void> load() async {
    final result = await _repository.currentEmail();
    if (isClosed) {
      return;
    }
    result.fold((_) {}, (email) => emit(state.copyWith(currentEmail: email)));
  }

  /// Checks the e-mail first (no request for an invalid or unchanged address); a second tap
  /// while sending is ignored.
  Future<void> submit({required String newEmail, required String password}) async {
    if (state.busy || state.locked) {
      return;
    }
    final email = newEmail.trim();
    if (!EmailChangeIssue.isValidEmail(email)) {
      emit(state.copyWith(issue: const EmailChangeIssue(EmailChangeIssueKind.invalidEmail)));
      return;
    }
    if (email.toLowerCase() == (state.currentEmail ?? '').toLowerCase()) {
      emit(state.copyWith(issue: const EmailChangeIssue(EmailChangeIssueKind.sameAsCurrent)));
      return;
    }
    emit(state.copyWith(busy: true, clearIssue: true));
    final result = await _repository.request(newEmail: email, currentPassword: password);
    if (isClosed) {
      return;
    }
    result.fold(
      (f) => emit(state.copyWith(busy: false, issue: EmailChangeIssue.from(f))),
      (_) => emit(state.copyWith(busy: false, sentTo: email)),
    );
  }

  /// Back from "check your e-mail" to the form, with the address kept in the field.
  void editAddress() => emit(state.copyWith(clearSent: true, clearIssue: true));

  /// The user typed again: the last answer no longer applies (a lock stays).
  void edited() {
    if (state.issue != null && !state.locked) {
      emit(state.copyWith(clearIssue: true));
    }
  }
}
