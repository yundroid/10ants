import 'package:sembast/sembast.dart';

/// Sembast koleksiyonları.
class Stores {
  static final users = intMapStoreFactory.store('users');
  static final properties = intMapStoreFactory.store('properties');
  static final tenants = intMapStoreFactory.store('tenants');
  static final transactions = intMapStoreFactory.store('transactions');
  static final meta = StoreRef<String, Object?>('meta');
}
