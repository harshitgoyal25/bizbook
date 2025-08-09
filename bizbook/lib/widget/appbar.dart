import 'package:bizbook/backend/auth.dart';
import 'package:bizbook/pages/add_sale.dart';
import 'package:bizbook/pages/billing.dart';
import 'package:bizbook/pages/dashboard.dart';
import 'package:bizbook/pages/inventory.dart';
import 'package:bizbook/pages/login.dart';
import 'package:bizbook/pages/manage_customers.dart';
import 'package:bizbook/pages/reports.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Widget drawer(BuildContext context, String name) {
  User? user = FirebaseAuth.instance.currentUser;
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            color: Color(0xFF7BA37E),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: user!.photoURL != null
                    ? SizedBox(
                        height: 40,
                        width: 40,
                        child: Image.network(user.photoURL ?? ""),
                      )
                    : Icon(
                        Icons.person,
                        size: 40,
                        color: Color(0xFF7BA37E),
                      ),
              ),
              SizedBox(height: 10),
              Text(
                user.displayName ?? "",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              Text(
                user.email ?? "",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dashboard),
          title: const Text('Dashboard'),
          selected: name == "Dashboard" ? true : false,
          selectedTileColor: Colors.green.withValues(alpha: 0.1),
          onTap: () {
            if (name == "Dashboard") return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => Dashboard(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.inventory),
          title: const Text('Inventory'),
          selected: name == "Inventory" ? true : false,
          selectedTileColor: Colors.green.withValues(alpha: 0.1),
          onTap: () {
            if (name == "Inventory") return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InventoryScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.people),
          title: const Text('Customers'),
          selected: name == "Customers" ? true : false,
          selectedTileColor: Colors.green.withValues(alpha: 0.1),
          onTap: () {
            if (name == "Customers") return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomersScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.receipt),
          selected: name == "Billings" ? true : false,
          selectedTileColor: Colors.green.withValues(alpha: 0.1),
          title: const Text('Billings'),
          onTap: () {
            if (name == "Billings") return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => Billing(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.bar_chart),
          title: const Text('Unpaid Orders'),
          selected: name == "Reports" ? true : false,
          selectedTileColor: Colors.green.withValues(alpha: 0.1),
          onTap: () {
            if (name == "Reports") return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => UnpaidOrdersReportScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.shopping_bag_outlined),
          title: const Text('Add Sales'),
          selected: name == "Add Sales" ? true : false,
          selectedTileColor: Colors.green.withValues(alpha: 0.1),
          onTap: () {
            if (name == "Add Sales") return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddSaleScreen(),
              ),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () {
            AuthService().signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LoginPage(),
              ),
            );
          },
        ),
      ],
    ),
  );
}

AppBar backAppBar(String name, BuildContext context, List<Widget>? actions) {
  return AppBar(
    actions: actions,
    backgroundColor: Color(0xFF7BA37E),
    leading: IconButton(
      onPressed: () {
        Navigator.pop(context);
      },
      icon: Icon(
        Icons.arrow_back_ios_outlined,
        color: Colors.white,
      ),
    ),
    title: Text(
      name,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

AppBar appbaar(String name, List<Widget>? actions) {
  int notificationCount = 1; // Example notification count
  return AppBar(
    backgroundColor: const Color(0xFF7BA37E),
    title: Text(
      name,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    leading: Builder(
      builder: (context) => IconButton(
        icon: const Icon(Icons.menu, color: Colors.white, size: 28),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
      ),
    ),
    actions: actions,
  );
}
