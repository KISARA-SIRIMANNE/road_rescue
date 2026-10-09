import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InsuranceCompany {
  const InsuranceCompany(this.id, this.name);

  final String id;
  final String name;
}

class InsuranceCompanyNotConfigured extends StateError {
  InsuranceCompanyNotConfigured()
    : super('Your insurance company is not configured. Select it to continue.');
}

const List<InsuranceCompany> insuranceCompanies = [
  InsuranceCompany(
    'sri_lanka_insurance_general',
    'Sri Lanka Insurance Corporation General Limited',
  ),
  InsuranceCompany('ceylinco_general', 'Ceylinco General Insurance'),
  InsuranceCompany('fairfirst', 'Fairfirst Insurance Limited'),
  InsuranceCompany('allianz_lanka', 'Allianz Insurance Lanka'),
  InsuranceCompany('janashakthi', 'Janashakthi Insurance'),
  InsuranceCompany('peoples_insurance', "People's Insurance PLC"),
  InsuranceCompany('hnb_general', 'HNB General Insurance'),
  InsuranceCompany('lolc_general', 'LOLC General Insurance'),
  InsuranceCompany('amana_takaful', 'Amana Takaful PLC'),
  InsuranceCompany('continental_lanka', 'Continental Insurance Lanka'),
];

InsuranceCompany? insuranceCompanyById(String? id) {
  if (id == null) return null;
  for (final company in insuranceCompanies) {
    if (company.id == id) return company;
  }
  return null;
}

Future<String> loadCurrentInsuranceCompanyId() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('Your insurance session has expired.');
  }

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  if (!snapshot.exists) {
    throw StateError('Your account information could not be found.');
  }

  final companyId = snapshot.data()?['insuranceCompanyId']?.toString();
  if (companyId == null || companyId.trim().isEmpty) {
    throw InsuranceCompanyNotConfigured();
  }
  if (insuranceCompanyById(companyId) == null) {
    throw StateError(
      'Your insurance company setting is invalid. Contact an administrator.',
    );
  }
  return companyId;
}
