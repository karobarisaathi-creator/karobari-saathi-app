import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static Map<String, Map<String, String>> _localizedValues = {
    'en': en,
    'ur': ur,
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]![key] ?? key;
  }

  // Helper methods for common translations
  String get appName => get('appName');
  String get dashboard => get('dashboard');
  String get transactions => get('transactions');
  String get accounts => get('accounts');
  String get reports => get('reports');
  String get settings => get('settings');
  String get login => get('login');
  String get logout => get('logout');
  String get save => get('save');
  String get cancel => get('cancel');
  String get delete => get('delete');
  String get edit => get('edit');
  String get view => get('view');
  String get add => get('add');
  String get search => get('search');
  String get filter => get('filter');
  String get income => get('income');
  String get expense => get('expense');
  String get balance => get('balance');
  String get amount => get('amount');
  String get date => get('date');
  String get time => get('time');
  String get description => get('description');
  String get category => get('category');
  String get agriculture => get('agriculture');
  String get shop => get('shop');
  String get property => get('property');
  String get services => get('services');
  String get phone => get('phone');
  String get address => get('address');
  String get name => get('name');
  String get email => get('email');
  String get password => get('password');
  String get confirmPassword => get('confirmPassword');
  String get submit => get('submit');
  String get reset => get('reset');
  String get back => get('back');
  String get next => get('next');
  String get finish => get('finish');
  String get skip => get('skip');
  String get continueText => get('continueText');
  String get ok => get('ok');
  String get yes => get('yes');
  String get no => get('no');
  String get success => get('success');
  String get error => get('error');
  String get warning => get('warning');
  String get info => get('info');
  String get loading => get('loading');
  String get noData => get('noData');
  String get tryAgain => get('tryAgain');
  String get connectionError => get('connectionError');
  String get serverError => get('serverError');
  String get unknownError => get('unknownError');

  String format(String key, List<dynamic> args) {
    String text = get(key);
    for (int i = 0; i < args.length; i++) {
      text = text.replaceAll('{$i}', args[i].toString());
    }
    return text;
  }

  // Account related
  String get addAccount => get('addAccount');
  String get editAccount => get('editAccount');
  String get accountName => get('accountName');
  String get accountBalance => get('accountBalance');
  String get initialBalance => get('initialBalance');
  String get currentBalance => get('currentBalance');
  String get totalBalance => get('totalBalance');
  String get received => get('received');
  String get gave => get('gave');
  String get iReceived => get('iReceived');
  String get iGave => get('iGave');
  String get balanceType => get('balanceType');
  String get party => get('party');
  String get parties => get('parties');
  String get addParty => get('addParty');
  String get editParty => get('editParty');
  String get partyDetails => get('partyDetails');
  String get partyName => get('partyName');
  String get partyPhone => get('partyPhone');
  String get partyAddress => get('partyAddress');
  String get partyCategory => get('partyCategory');
  String get general => get('general');
  String get supplier => get('supplier');
  String get family => get('family');
  String get friend => get('friend');
  String get business => get('business');
  String get other => get('other');

  // Transaction related
  String get addTransaction => get('addTransaction');
  String get editTransaction => get('editTransaction');
  String get transactionDetails => get('transactionDetails');
  String get transactionType => get('transactionType');
  String get transactionDate => get('transactionDate');
  String get transactionAmount => get('transactionAmount');
  String get transactionCategory => get('transactionCategory');
  String get transactionDescription => get('transactionDescription');
  String get pendingAmount => get('pendingAmount');
  String get receivedAmount => get('receivedAmount');
  String get totalAmount => get('totalAmount');
  String get paymentMethod => get('paymentMethod');
  String get referenceNumber => get('referenceNumber');
  String get cash => get('cash');
  String get bank => get('bank');
  String get online => get('online');
  String get cheque => get('cheque');
  String get pending => get('pending');
  String get completed => get('completed');
  String get cancelled => get('cancelled');

  // Profession related
  String get professions => get('professions');
  String get addProfession => get('addProfession');
  String get editProfession => get('editProfession');
  String get deleteProfession => get('deleteProfession');
  String get deleteProfessionConfirm => get('deleteProfessionConfirm');
  String get newProfession => get('newProfession');
  String get selectIcon => get('selectIcon');
  String get professionName => get('professionName');
  String get professionDescription => get('professionDescription');
  String get seasonYear => get('seasonYear');
  String get seasonHint => get('seasonHint');
  String get seasonNote => get('seasonNote');
  String get enterProfessionName => get('enterProfessionName');
  String get food => get('food');
  String get tech => get('tech');
  String get finance => get('finance');
  String get fitness => get('fitness');
  String get shopping => get('shopping');
  String get laptop => get('laptop');
  String get factory => get('factory');
  String get hammer => get('hammer');
  String get totalIncome => get('totalIncome');
  String get totalExpense => get('totalExpense');
  String get netProfit => get('netProfit');
  String get profitMargin => get('profitMargin');
  String get active => get('active');
  String get inactive => get('inactive');
  String get complete => get('complete');
  String get activate => get('activate');
  String get manageCategories => get('manageCategories');
  String get financialSummary => get('financialSummary');
  String get noTransactions => get('noTransactions');
  String get smartRecommendations => get('smartRecommendations');
  String get transaction => get('transaction');
  String get profit => get('profit');
  String get loss => get('loss');
  String get incomeCategories => get('incomeCategories');
  String get expenseCategories => get('expenseCategories');
  String get addNewCategory => get('addNewCategory');
  String get costPerUnit => get('costPerUnit');
  String get profitPerUnit => get('profitPerUnit');
  String get salary => get('salary');
  String get freelance => get('freelance');
  String get rent => get('rent');
  String get electricity => get('electricity');
  String get water => get('water');
  String get transport => get('transport');
  String get productionYield => get('productionYield');
  String get enterAmount => get('enterAmount');
  String get amountReceived => get('amountReceived');
  String get amountPaid => get('amountPaid');
  String get confirmDelete => get('confirmDelete');
  String get kg => get('kg');
  String get gram => get('gram');
  String get ton => get('ton');
  String get man => get('man');
  String get litre => get('litre');
  String get dozen => get('dozen');
  String get piece => get('piece');

  // Profession Categories
  String get manufacturing => get('manufacturing');
  String get retail => get('retail');
  String get construction => get('construction');
  String get education => get('education');
  String get healthcare => get('healthcare');
  String get transportation => get('transportation');

  // Reports related
  String get financialReport => get('financialReport');
  String get monthlyReport => get('monthlyReport');
  String get yearlyReport => get('yearlyReport');
  String get categoryReport => get('categoryReport');
  String get profitLoss => get('profitLoss');
  String get incomeExpense => get('incomeExpense');
  String get chart => get('chart');
  String get summary => get('summary');
  String get details => get('details');
  String get export => get('export');
  String get print => get('print');
  String get share => get('share');

  // Settings related
  String get language => get('language');
  String get theme => get('theme');
  String get darkMode => get('darkMode');
  String get lightMode => get('lightMode');
  String get systemDefault => get('systemDefault');
  String get backup => get('backup');
  String get restore => get('restore');
  String get sync => get('sync');
  String get security => get('security');
  String get privacy => get('privacy');
  String get about => get('about');
  String get help => get('help');
  String get contactUs => get('contactUs');
  String get rateApp => get('rateApp');
  String get shareApp => get('shareApp');
  String get version => get('version');

  // Notifications
  String get notifications => get('notifications');
  String get markAllRead => get('markAllRead');
  String get clearAll => get('clearAll');
  String get newNotification => get('newNotification');
  String get transactionNotification => get('transactionNotification');
  String get reminderNotification => get('reminderNotification');
  String get reportNotification => get('reportNotification');

  // Validation messages
  String get requiredField => get('requiredField');
  String get invalidPhone => get('invalidPhone');
  String get invalidEmail => get('invalidEmail');
  String get invalidAmount => get('invalidAmount');
  String get invalidName => get('invalidName');
  String get passwordMismatch => get('passwordMismatch');
  String get weakPassword => get('weakPassword');

  // Success messages
  String get savedSuccessfully => get('savedSuccessfully');
  String get updatedSuccessfully => get('updatedSuccessfully');
  String get deletedSuccessfully => get('deletedSuccessfully');
  String get addedSuccessfully => get('addedSuccessfully');
  String get backupSuccess => get('backupSuccess');
  String get restoreSuccess => get('restoreSuccess');
  String get syncSuccess => get('syncSuccess');

  // Error messages
  String get saveError => get('saveError');
  String get updateError => get('updateError');
  String get deleteError => get('deleteError');
  String get addError => get('addError');
  String get backupError => get('backupError');
  String get restoreError => get('restoreError');
  String get syncError => get('syncError');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ur'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
