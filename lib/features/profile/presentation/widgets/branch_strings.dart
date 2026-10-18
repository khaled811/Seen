// Copy for the branches screen (Figma ACC-07).
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../bloc/branches_cubit.dart';

extension BranchStrings on SeenStrings {
  String _t(String ar, String en) => isArabic ? ar : en;

  String get branchesTitle => _t('الفروع', 'Branches');
  String get requestsByBranch => _t('عرض الطلبات حسب الفرع', 'View requests by branch');
  String get allBranches => _t('كل الفروع', 'All branches');
  String branchStaffTitle(String name) => _t('$name · الموظفون', '$name · staff');
  String get moveToBranch => _t('نقل لفرع', 'Move to a branch');
  String get assignStaffToBranch => _t('تعيين موظف لفرع', 'Assign a staff member to a branch');
  String get addBranch => _t('إضافة فرع', 'Add a branch');
  String get branchNameLabel => _t('اسم الفرع', 'Branch name');
  String get chooseStaff => _t('اختر الموظف', 'Choose the staff member');
  String get chooseBranch => _t('اختر الفرع', 'Choose the branch');
  String get noStaffInBranch => _t('لا موظفين في هذا الفرع بعد.', 'No staff in this branch yet.');
  String get noOneToAssign => _t('لا يوجد موظفون لتعيينهم.', 'There is nobody to assign.');
  String get createAction => _t('إنشاء', 'Create');
  String get branchNameRequired => _t('اكتب اسم الفرع.', 'Enter the branch name.');
  String branchesLoadFailed() => _t('تعذّر تحميل الفروع.', 'Could not load the branches.');
  String branchNotice(BranchNotice n) => switch (n) {
        BranchNotice.created => _t('تمت إضافة الفرع.', 'Branch added.'),
        BranchNotice.assigned => _t('تم تعيين الموظف.', 'Staff member assigned.'),
        BranchNotice.failed => _t('تعذّر تنفيذ الإجراء. حاول مرة أخرى.', 'Could not do that. Try again.'),
      };

  String staffCountLabel(int n) {
    if (!isArabic) {
      return n == 1 ? '1 staff member' : '$n staff';
    }
    return switch (n) {
      0 => 'لا موظفين',
      1 => 'موظف واحد',
      2 => 'موظفان',
      >= 3 && <= 10 => '${numeral(n)} موظفين',
      _ => '${numeral(n)} موظفًا',
    };
  }

  String requestCountLabel(int n) {
    if (!isArabic) {
      return n == 1 ? '1 request' : '$n requests';
    }
    return switch (n) {
      0 => 'لا طلبات',
      1 => 'طلب واحد',
      2 => 'طلبان',
      >= 3 && <= 10 => '${numeral(n)} طلبات',
      _ => '${numeral(n)} طلبًا',
    };
  }
}
