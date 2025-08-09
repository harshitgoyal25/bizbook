import 'package:bizbook/backend/customer.dart';
import 'package:bizbook/backend/inventory.dart';
import 'package:bizbook/backend/sale_model.dart';
import 'package:firebase_database/firebase_database.dart';

class DatabaseRepository {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Sales methods
  Future<List<Sale>> getSales() async {
    try {
      final salesSnapshot = await _database.child('sales').get();
      if (!salesSnapshot.exists) return [];

      final salesData = salesSnapshot.value as Map<dynamic, dynamic>;
      List<Sale> salesList = [];

      salesData.forEach((key, value) {
        salesList.add(Sale.fromMap(key, value));
      });

      return salesList;
    } catch (e) {
      return [];
    }
  }

  Future<Sale?> getSaleById(String id) async {
    try {
      final saleSnapshot = await _database.child('sales').child(id).get();
      if (!saleSnapshot.exists) return null;

      return Sale.fromMap(id, saleSnapshot.value as Map<dynamic, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<String> addSale(Sale sale) async {
    try {
      final newSaleRef = _database.child('sales').push();
      await newSaleRef.set(sale.toMap());

      // Update customer data
      await _database.child('customers').child(sale.customerId).update({
        'totalSpent': ServerValue.increment(sale.amount),
        'totalOrders': ServerValue.increment(1),
      });

      return newSaleRef.key!;
    } catch (e) {
      throw Exception('Failed to add sale: $e');
    }
  }

  // Customer methods
  Future<List<Customer>> getCustomers() async {
    try {
      final customersSnapshot = await _database.child('customers').get();
      if (!customersSnapshot.exists) return [];

      final customersData = customersSnapshot.value as Map<dynamic, dynamic>;
      List<Customer> customersList = [];

      customersData.forEach((key, value) {
        customersList.add(Customer.fromMap(key, value));
      });

      return customersList;
    } catch (e) {
      return [];
    }
  }

  Future<Customer?> getCustomerById(String id) async {
    try {
      final customerSnapshot =
          await _database.child('customers').child(id).get();
      if (!customerSnapshot.exists) return null;

      return Customer.fromMap(
          id, customerSnapshot.value as Map<dynamic, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<List<Customer>> getNewCustomersToday() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final customersSnapshot = await _database
          .child('customers')
          .orderByChild('createdAt')
          .startAt(today)
          .endAt('$today\uf8ff')
          .get();

      if (!customersSnapshot.exists) return [];

      final customersData = customersSnapshot.value as Map<dynamic, dynamic>;
      List<Customer> customersList = [];

      customersData.forEach((key, value) {
        customersList.add(Customer.fromMap(key, value));
      });

      return customersList;
    } catch (e) {
      return [];
    }
  }

  // Inventory methods
  Future<List<InventoryItem>> getInventory() async {
    try {
      final inventorySnapshot = await _database.child('inventory').get();
      if (!inventorySnapshot.exists) return [];

      final inventoryData = inventorySnapshot.value as Map<dynamic, dynamic>;
      List<InventoryItem> inventoryList = [];

      inventoryData.forEach((key, value) {
        inventoryList.add(InventoryItem.fromMap(key, value));
      });

      return inventoryList;
    } catch (e) {
      return [];
    }
  }

  Future<List<InventoryItem>> getLowStockItems() async {
    try {
      final inventorySnapshot = await _database
          .child('inventory')
          .orderByChild('quantity')
          .endAt(9) // Items with quantity less than 10
          .get();

      if (!inventorySnapshot.exists) return [];

      final inventoryData = inventorySnapshot.value as Map<dynamic, dynamic>;
      List<InventoryItem> lowStockList = [];

      inventoryData.forEach((key, value) {
        lowStockList.add(InventoryItem.fromMap(key, value));
      });

      return lowStockList;
    } catch (e) {
      return [];
    }
  }

  // Summary methods
  Future<Map<String, dynamic>> getDailySummary() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Get today's sales
      final salesSnapshot = await _database
          .child('sales')
          .orderByChild('date')
          .equalTo(today)
          .get();

      int salesCount = 0;
      double todayRevenue = 0;
      List<Sale> recentSales = [];

      if (salesSnapshot.exists) {
        final salesData = salesSnapshot.value as Map<dynamic, dynamic>;
        salesCount = salesData.length;
        salesData.forEach((key, value) {
          final sale = Sale.fromMap(key, value);
          todayRevenue += sale.amount;
          recentSales.add(sale);
        });
      }

      // Sort recent sales by timestamp (newest first)
      recentSales.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Get weekly revenue
      final weekStart =
          DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
      final weekStartStr = weekStart.toIso8601String().split('T')[0];

      final weeklySnapshot = await _database
          .child('sales')
          .orderByChild('date')
          .startAt(weekStartStr)
          .endAt(today)
          .get();

      double weeklyRevenue = 0.0;

      if (weeklySnapshot.exists) {
        final weeklyData = weeklySnapshot.value as Map<dynamic, dynamic>;

        weeklyData.forEach((key, value) {
          weeklyRevenue += (value['amount'] ?? 0.0).toDouble();
        });
      }

      // Get new customers today
      final newCustomers = await getNewCustomersToday();

      // Get inventory stats
      final inventory = await getInventory();
      final lowStockItems = inventory.where((item) => item.isLowStock).toList();

      return {
        'todaySales': salesCount,
        'todayRevenue': todayRevenue,
        'weeklyRevenue': weeklyRevenue,
        'newCustomers': newCustomers.length,
        'totalInventory': inventory.length,
        'lowStockItems': lowStockItems.length,
        'recentSales': recentSales.take(5).toList(),
      };
    } catch (e) {
      return {
        'todaySales': 0,
        'todayRevenue': 0.0,
        'weeklyRevenue': 0.0,
        'newCustomers': 0,
        'totalInventory': 0,
        'lowStockItems': 0,
        'recentSales': [],
      };
    }
  }
}
