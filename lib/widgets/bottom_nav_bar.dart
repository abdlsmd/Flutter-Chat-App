import 'package:flutter/material.dart';
import 'package:chat_app/screens/current_user_info.dart';
import 'package:chat_app/screens/user_list_screen.dart';

class CustomBottomNavBar extends StatelessWidget {
  final bool isInboxSelected;

  const CustomBottomNavBar({
    super.key,
    required this.isInboxSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: Icon(
              Icons.chat,
              color: isInboxSelected ? Colors.blue : Colors.grey,
            ),
            onPressed: () {
              if (!isInboxSelected) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) =>  UsersListScreen(),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.person,
              color: !isInboxSelected ? Colors.blue : Colors.grey,
            ),
            onPressed: () {
              if (isInboxSelected) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => const CurrentUserInfoScreen(),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}