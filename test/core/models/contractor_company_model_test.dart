import 'package:account_app/core/models/contractor_company_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads only public company name and business area', () {
    final company = ContractorCompany.fromMap('company-1', {
      'companyName': 'Karobari Builders',
      'businessArea': 'Lahore',
      'phoneNumber': '03001234567',
      'contractAmount': 500000,
    });

    expect(company.id, 'company-1');
    expect(company.name, 'Karobari Builders');
    expect(company.businessArea, 'Lahore');
  });

  test('trims public fields and supports missing values', () {
    final company = ContractorCompany.fromMap('company-2', {
      'companyName': '  Builders  ',
      'businessArea': '  Lahore  ',
    });
    final emptyCompany = ContractorCompany.fromMap('company-3', {});

    expect(company.name, 'Builders');
    expect(company.businessArea, 'Lahore');
    expect(emptyCompany.name, isEmpty);
    expect(emptyCompany.businessArea, isEmpty);
  });
}
