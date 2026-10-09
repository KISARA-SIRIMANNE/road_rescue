import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InsuranceCompany {
  const InsuranceCompany(this.id, this.name);

  final String id;
  final String name;
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

  final snapshot =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  final id = snapshot.data()?['insuranceCompanyId']?.toString();
  if (!snapshot.exists || insuranceCompanyById(id) == null) {
    throw StateError(
      'Your insurance company is not configured. Contact an administrator.',
    );
  }
  return id!;
}
