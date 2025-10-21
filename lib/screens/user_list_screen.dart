import 'package:chat_app/widgets/bottom_nav_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'user_info.dart';
import 'chat.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final Set<String> _pendingDelete = {};
  final Map<String, bool> _undoRequested = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
  }

  void _scheduleDelete(String userId, String username) {
    _undoRequested[userId] = false;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed $username'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            _undoRequested[userId] = true;
            setState(() => _pendingDelete.remove(userId));
          },
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 5), () async {
      final cancelled = _undoRequested[userId] == true;
      _undoRequested.remove(userId);

      if (!mounted) return;

      if (cancelled) {
        return;
      }

      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      } catch (e) {
        if (mounted) {
          setState(() => _pendingDelete.remove(userId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete $username: $e')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by name...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color.fromARGB(179, 0, 0, 0)),
                ),
                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                cursorColor: const Color.fromARGB(255, 0, 0, 0),
                onChanged: (_) => setState(() {}),
              )
            : const Text('All Users'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _startSearch,
            ),
          IconButton(
            icon: Icon(Icons.exit_to_app,
                color: Theme.of(context).colorScheme.primary),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (ctx, usersSnapshot) {
          if (usersSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!usersSnapshot.hasData || usersSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          var allUsers = usersSnapshot.data!.docs
              .where((d) => d.id != currentUser.uid)
              .toList();

          if (_searchController.text.trim().isNotEmpty) {
            allUsers = allUsers.where((user) {
              final username = (user.data() as Map<String, dynamic>)['username']
                      ?.toString()
                      .toLowerCase() ??
                  '';
              return username
                  .contains(_searchController.text.trim().toLowerCase());
            }).toList();
          }

          if (allUsers.isEmpty) {
            return const Center(child: Text('No matching users found'));
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(allUsers.map((userDoc) async {
              final userData = userDoc.data() as Map<String, dynamic>;
              final participants = [currentUser.uid, userDoc.id]..sort();
              final conversationId = participants.join('_');
              final convSnap = await FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(conversationId)
                  .get();

              DateTime? lastAt;
              String lastMessage = '';
              if (convSnap.exists) {
                final ts = convSnap.data()?['lastMessageAt'];
                if (ts is Timestamp) lastAt = ts.toDate();
                lastMessage = convSnap.data()?['lastMessage'] ?? '';
              }

              return {
                'userId': userDoc.id,
                'userData': userData,
                'lastAt': lastAt,
                'lastMessage': lastMessage,
              };
            }).toList()),
            builder: (ctx2, combinedSnap) {
              if (combinedSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var items = combinedSnap.data ?? [];

              items = items
                  .where((m) => !_pendingDelete.contains(m['userId'] as String))
                  .toList();

              items.sort((a, b) {
                final aAt = a['lastAt'] as DateTime?;
                final bAt = b['lastAt'] as DateTime?;
                if (aAt == null && bAt == null) {
                  final an = (a['userData']['username'] ?? '').toString();
                  final bn = (b['userData']['username'] ?? '').toString();
                  return an.compareTo(bn);
                }
                if (aAt == null) return 1;
                if (bAt == null) return -1;
                return bAt.compareTo(aAt);
              });

              return RefreshIndicator(
                onRefresh: () async {
                  // Force a rebuild when user pulls down
                  setState(() {});
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 0.5),
                  itemBuilder: (ctx3, i) {
                    final item = items[i];
                    final userId = item['userId'] as String;
                    final userData = item['userData'] as Map<String, dynamic>;
                    final lastMessage = (item['lastMessage'] as String?) ?? '';
                    final lastAt = item['lastAt'] as DateTime?;

                    final subtitle =
                        lastMessage.isNotEmpty ? lastMessage : 'Tap to chat';

                    final trailing = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (lastAt != null)
                          Text(DateFormat.jm().format(lastAt),
                              style: const TextStyle(fontSize: 12)),
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => UserInfoScreen(
                                  userId: userId,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );

                    return Dismissible(
                      key: Key(userId),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        setState(() => _pendingDelete.add(userId));
                        _scheduleDelete(
                            userId, (userData['username'] ?? 'user').toString());
                        return false;
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(
                            (userData['image'] as String?) ??
                                'https://via.placeholder.com/150/cccccc/000000?text=User',
                          ),
                        ),
                        title: Text(userData['username'] ?? 'Unknown'),
                        subtitle: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: trailing,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => ChatScreen(
                                receiverId: userId,
                                receiverUsername:
                                    userData['username'] ?? 'Unknown',
                                receiverImage: userData['image'] ?? '',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: const CustomBottomNavBar(
        isInboxSelected: true,
      ),
    );
  }
}
