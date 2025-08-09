import 'package:bizbook/backend/auth.dart';
import 'package:bizbook/backend/customer.dart';
import 'package:bizbook/backend/inventory.dart';
import 'package:bizbook/backend/sale_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:bizbook/widget/appbar.dart';

class AddSaleScreen extends StatefulWidget {
  final Customer? preSelectedCustomer;

  const AddSaleScreen({super.key, this.preSelectedCustomer});

  @override
  AddSaleScreenState createState() => AddSaleScreenState();
}

class AddSaleScreenState extends State<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Customer? _selectedCustomer;
  List<Customer> _customers = [];
  List<InventoryItem> _inventoryItems = [];
  List<SaleItem> saleItems = [];

  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = 'Cash';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.preSelectedCustomer;
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load customers
      final customersSnapshot = await _database.child('customers').once();
      if (customersSnapshot.snapshot.value != null) {
        final customersData =
            customersSnapshot.snapshot.value as Map<dynamic, dynamic>;
        _customers = [];

        customersData.forEach((key, value) {
          final customer =
              Customer.fromMap(key, value as Map<dynamic, dynamic>);
          _customers.add(customer);
        });

        // Sort customers by name
        _customers.sort((a, b) => a.name.compareTo(b.name));
      }

      // Load inventory items
      final inventorySnapshot = await _database.child('inventory').once();
      if (inventorySnapshot.snapshot.value != null) {
        final inventoryData =
            inventorySnapshot.snapshot.value as Map<dynamic, dynamic>;
        _inventoryItems = [];

        inventoryData.forEach((key, value) {
          final item =
              InventoryItem.fromMap(key, value as Map<dynamic, dynamic>);
          _inventoryItems.add(item);
        });

        // Sort items by name
        _inventoryItems.sort((a, b) => a.name.compareTo(b.name));
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  void _addItem(InventoryItem item) {
    // Check if item already exists in sale
    final existingItemIndex =
        saleItems.indexWhere((saleItem) => saleItem.itemId == item.id);

    setState(() {
      if (existingItemIndex >= 0) {
        // Increment quantity if item already exists
        final existingItem = saleItems[existingItemIndex];
        final inventoryItem = _inventoryItems
            .firstWhere((inventoryItem) => inventoryItem.id == item.id);

        // Check if adding more exceeds inventory quantity
        if (existingItem.quantity + 1 > inventoryItem.quantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Cannot add more ${item.name}, not enough stock')),
          );
          return;
        }

        saleItems[existingItemIndex] = SaleItem(
          itemId: existingItem.itemId,
          itemName: existingItem.itemName,
          price: existingItem.price,
          quantity: existingItem.quantity + 1,
          imageUrl: existingItem.imageUrl,
        );
      } else {
        // Add new item with quantity 1
        if (item.quantity <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${item.name} is out of stock')),
          );
          return;
        }

        saleItems.add(SaleItem(
          itemId: item.id,
          itemName: item.name,
          price: item.price,
          quantity: 1,
          imageUrl: item.imageUrl,
        ));
      }

      // Reduce the quantity of the item in inventory
      final inventoryItemIndex = _inventoryItems
          .indexWhere((inventoryItem) => inventoryItem.id == item.id);
      if (inventoryItemIndex >= 0) {
        final inventoryItem = _inventoryItems[inventoryItemIndex];
        if (inventoryItem.quantity > 0) {
          _inventoryItems[inventoryItemIndex] = InventoryItem(
            id: inventoryItem.id,
            name: inventoryItem.name,
            price: inventoryItem.price,
            quantity: inventoryItem.quantity - 1,
            imageUrl: inventoryItem.imageUrl,
            createdAt: inventoryItem.createdAt,
            updatedAt: inventoryItem.updatedAt,
            lastTimeStamp: inventoryItem.lastTimeStamp,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${item.name} is out of stock')),
          );
        }
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      saleItems.removeAt(index);
    });
  }

  void _updateItemQuantity(int index, int quantity) {
    if (quantity <= 0) {
      _removeItem(index);
      return;
    }

    final item = saleItems[index];
    final inventoryItem = _inventoryItems
        .firstWhere((inventoryItem) => inventoryItem.id == item.itemId);

    // Check if the new quantity exceeds inventory quantity
    if (quantity > inventoryItem.quantity) {
      AuthService().showToast(
        context,
        "Cannot increase quantity for ${item.itemName}, not enough stock",
        false,
      );
      return;
    }

    setState(() {
      saleItems[index] = SaleItem(
        itemId: item.itemId,
        itemName: item.itemName,
        price: item.price,
        quantity: quantity,
        imageUrl: item.imageUrl,
      );
    });
  }

  double get _totalAmount {
    return saleItems.fold(0, (sum, item) => sum + item.total);
  }

  Future<void> _selectCustomer() async {
    final selectedCustomer = await showDialog<Customer>(
      context: context,
      builder: (context) => CustomerSelectionDialog(customers: _customers),
    );

    if (selectedCustomer != null) {
      setState(() {
        _selectedCustomer = selectedCustomer;
      });
    }
  }

  Future<void> _saveSale() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_selectedCustomer == null) {
      AuthService().showToast(context, 'Please select a customer', false);
      return;
    }

    if (saleItems.isEmpty) {
      AuthService().showToast(context, 'Please add at least one item', false);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();

      // Create new sale
      final newSaleRef = _database.child('sales').push();
      final sale = Sale(
        id: newSaleRef.key!,
        customerId: _selectedCustomer!.customerId,
        customerName: _selectedCustomer!.name,
        amount: _totalAmount,
        date: now,
        items: saleItems,
        paymentMethod: _paymentMethod,
        notes: _notesController.text,
        timestamp: now.millisecondsSinceEpoch,
      );

      // Save sale to database
      await newSaleRef.set(sale.toMap());

      // Update customer data (totalSpent and totalOrders)
      final customerRef =
          _database.child('customers').child(_selectedCustomer!.id);
      await customerRef.update({
        'totalSpent': ServerValue.increment(_totalAmount),
        'totalOrders': ServerValue.increment(1),
      });

      // Update inventory quantities
      for (final saleItem in saleItems) {
        final inventoryItemIndex = _inventoryItems
            .indexWhere((inventoryItem) => inventoryItem.id == saleItem.itemId);
        if (inventoryItemIndex >= 0) {
          final inventoryItem = _inventoryItems[inventoryItemIndex];
          final newQuantity = inventoryItem.quantity - saleItem.quantity;

          if (newQuantity < 0) {
            if (!mounted) return;
            AuthService().showToast(
              context,
              "Cannot decrease quantity for ${inventoryItem.name}, not enough stock",
              false,
            );
            continue;
          }

          _inventoryItems[inventoryItemIndex] = InventoryItem(
            id: inventoryItem.id,
            name: inventoryItem.name,
            price: inventoryItem.price,
            quantity: newQuantity,
            imageUrl: inventoryItem.imageUrl,
            createdAt: inventoryItem.createdAt,
            updatedAt: inventoryItem.updatedAt,
            lastTimeStamp: inventoryItem.lastTimeStamp,
          );

          // Update the inventory in the database
          await _database.child('inventory').child(inventoryItem.id).update({
            'quantity': newQuantity,
          });
        }
      }

      // Show success message and go back
      if (mounted) {
        AuthService().showToast(context, "Sale added successfully", true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (!mounted) return;
      AuthService().showToast(context, 'Failed to save sale: $e', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: backAppBar('Add Sale', context, []),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B5E5A)))
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer selection
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2EBE6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Customer',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B5E5A),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_selectedCustomer != null)
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.white,
                                        backgroundImage: _selectedCustomer!
                                                        .photoUrl !=
                                                    null &&
                                                _selectedCustomer!
                                                    .photoUrl!.isNotEmpty
                                            ? NetworkImage(
                                                _selectedCustomer!.photoUrl!)
                                            : null,
                                        child: _selectedCustomer!.photoUrl ==
                                                    null ||
                                                _selectedCustomer!
                                                    .photoUrl!.isEmpty
                                            ? const Icon(
                                                Icons.person,
                                                size: 24,
                                                color: Color(0xFF8B5E5A),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedCustomer!.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF8B5E5A),
                                              ),
                                            ),
                                            Text(
                                              _selectedCustomer!.email,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Color(0xFF8B5E5A)),
                                        onPressed: _selectCustomer,
                                      ),
                                    ],
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: _selectCustomer,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B5E5A),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Select Customer',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Items section
                          const Text(
                            'Items',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B5E5A),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Selected items list
                          if (saleItems.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2EBE6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: saleItems.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = saleItems[index];
                                  return Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        if (item.imageUrl != null &&
                                            item.imageUrl!.isNotEmpty)
                                          Container(
                                            width: 40,
                                            height: 40,
                                            margin: const EdgeInsets.only(
                                                right: 12),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              image: DecorationImage(
                                                image: NetworkImage(
                                                    item.imageUrl!),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            width: 40,
                                            height: 40,
                                            margin: const EdgeInsets.only(
                                                right: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade300,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                              size: 20,
                                            ),
                                          ),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.itemName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF8B5E5A),
                                                ),
                                              ),
                                              Text(
                                                '₹${item.price.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  color: Color(0xFF8B5E5A)),
                                              onPressed: () =>
                                                  _updateItemQuantity(
                                                      index, item.quantity - 1),
                                              iconSize: 20,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${item.quantity}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF8B5E5A),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.add_circle_outline,
                                                  color: Color(0xFF8B5E5A)),
                                              onPressed: () =>
                                                  _updateItemQuantity(
                                                      index, item.quantity + 1),
                                              iconSize: 20,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '₹${item.total.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF8B5E5A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Add items button
                          ElevatedButton.icon(
                            onPressed: () => _showItemSelectionDialog(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5E5A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text(
                              'Add Items',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Payment method
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2EBE6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment Method',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B5E5A),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _paymentMethod,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                  items: [
                                    'Cash',
                                    'Credit Card',
                                    'Debit Card',
                                    'UPI',
                                    'Bank Transfer'
                                  ]
                                      .map((method) => DropdownMenuItem(
                                            value: method,
                                            child: Text(method),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _paymentMethod = value;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Notes
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2EBE6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Notes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B5E5A),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _notesController,
                                  decoration: const InputDecoration(
                                    hintText: 'Add notes (optional)',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom total and save button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8B5E5A),
                                ),
                              ),
                              Text(
                                '₹${_totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8B5E5A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveSale,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5E5A),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save Sale',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _showItemSelectionDialog() async {
    await showDialog(
      context: context,
      builder: (context) => ItemSelectionDialog(
        inventoryItems: _inventoryItems,
        onItemSelected: _addItem,
      ),
    );
  }
}

class CustomerSelectionDialog extends StatefulWidget {
  final List<Customer> customers;

  const CustomerSelectionDialog({
    super.key,
    required this.customers,
  });

  @override
  CustomerSelectionDialogState createState() => CustomerSelectionDialogState();
}

class CustomerSelectionDialogState extends State<CustomerSelectionDialog> {
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _filteredCustomers = List.from(widget.customers);
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = List.from(widget.customers);
      } else {
        _filteredCustomers = widget.customers.where((customer) {
          return customer.name.toLowerCase().contains(query.toLowerCase()) ||
              customer.email.toLowerCase().contains(query.toLowerCase()) ||
              customer.phoneNumber.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Customer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B5E5A),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search customers',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _filterCustomers,
            ),
            const SizedBox(height: 16),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: _filteredCustomers.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No customers found'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.white,
                            backgroundImage: customer.photoUrl != null &&
                                    customer.photoUrl!.isNotEmpty
                                ? NetworkImage(customer.photoUrl!)
                                : null,
                            child: customer.photoUrl == null ||
                                    customer.photoUrl!.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: Color(0xFF8B5E5A),
                                  )
                                : null,
                          ),
                          title: Text(
                            customer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B5E5A),
                            ),
                          ),
                          subtitle: Text(customer.email),
                          onTap: () => Navigator.pop(context, customer),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF8B5E5A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ItemSelectionDialog extends StatefulWidget {
  final List<InventoryItem> inventoryItems;
  final Function(InventoryItem) onItemSelected;

  const ItemSelectionDialog({
    super.key,
    required this.inventoryItems,
    required this.onItemSelected,
  });

  @override
  ItemSelectionDialogState createState() => ItemSelectionDialogState();
}

class ItemSelectionDialogState extends State<ItemSelectionDialog> {
  List<InventoryItem> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.inventoryItems);
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(widget.inventoryItems);
      } else {
        _filteredItems = widget.inventoryItems.where((item) {
          return item.name.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Item',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B5E5A),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search items',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _filterItems,
            ),
            const SizedBox(height: 16),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: _filteredItems.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No items found'),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return InkWell(
                          onTap: () {
                            widget.onItemSelected(item);
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2EBE6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (item.imageUrl.isNotEmpty)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Image.network(
                                        item.imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return const Icon(
                                            Icons.image,
                                            size: 40,
                                            color: Colors.black54,
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                else
                                  const Expanded(
                                    child: Icon(
                                      Icons.image,
                                      size: 40,
                                      color: Colors.black54,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF8B5E5A),
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${item.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Color(0xFF8B5E5A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF8B5E5A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
