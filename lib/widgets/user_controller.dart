import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersController extends GetxController {
  var allUsers = <Map<String, dynamic>>[].obs;
  var searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUsers();
  }

  void fetchUsers() {
    FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
      allUsers.value = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'username': data['username'] ?? '',
          'email': data['email'] ?? '',
          'image_url': data['image_url'] ?? '',
        };
      }).toList();
    });
  }

  List<Map<String, dynamic>> get filteredUsers {
    if (searchQuery.value.isEmpty) {
      return allUsers;
    }
    final query = searchQuery.value.toLowerCase();
    return allUsers
        .where((user) =>
            (user['username'] ?? '').toLowerCase().contains(query) ||
            (user['email'] ?? '').toLowerCase().contains(query))
        .toList();
  }

  void removeUserAt(int index) {
    if (index >= 0 && index < allUsers.length) {
      allUsers.removeAt(index);
    }
  }

  void insertUserAt(int index, Map<String, dynamic> user) {
    allUsers.insert(index, user);
  }

  bool containsUser(String id) {
    return allUsers.any((user) => user['id'] == id);
  }
}
