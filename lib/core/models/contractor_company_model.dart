class ContractorCompany {
  final String id;
  final String name;
  final String businessArea;

  const ContractorCompany({
    required this.id,
    required this.name,
    required this.businessArea,
  });

  factory ContractorCompany.fromMap(String id, Map<String, dynamic> data) =>
      ContractorCompany(
        id: id,
        name: (data['companyName'] ?? '').toString().trim(),
        businessArea: (data['businessArea'] ?? '').toString().trim(),
      );
}
