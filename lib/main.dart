import 'package:flutter/material.dart';
import 'pass.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('[main] Firebase initialization successful');
  } catch (e) {
    print('[main] Firebase initialization error: $e');
    // Even if Firebase initialization fails, the app will start
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Customer Management',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black54,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _authenticated = false;
  bool _loading = false;

  void _onAuthenticated() async {
    setState(() => _loading = true);
    // You can add pre-await processing here if needed
    await Future.delayed(const Duration(milliseconds: 300)); // Dummy loading
    setState(() {
      _authenticated = true;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_authenticated) {
      return const CustomerListPage();
    } else {
      return PasswordGate(onAuthenticated: _onAuthenticated);
    }
  }
}

class Customer {
  final int number;
  final String name;
  final String phone;
  final String memo;
  List<Order> orders;
  Customer({
    required this.number,
    required this.name,
    required this.phone,
    required this.memo,
    required this.orders,
  });
}

class Order {
  final String orderId;
  final String date;
  Order({required this.orderId, required this.date});
}

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  static const int customersPerPage = 500;
  int? _expandedCustomerIndex; // Index of the expanded customer

  // Data
  late List<Customer> allCustomers;
  List<Customer> filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      // 顧客データを読み込み
      final customerSnapshot = await FirebaseFirestore.instance
          .collection('Customers')
          .get();
      final customers = customerSnapshot.docs
          .map((doc) {
            try {
              final data = doc.data();

              // numberフィールドの型を安全に処理
              int number;
              if (data['number'] is int) {
                number = data['number'] as int;
              } else if (data['number'] is String) {
                number = int.tryParse(data['number'] as String) ?? 0;
              } else {
                number = 0;
              }

              // 他のフィールドも安全に処理
              final name = data['name']?.toString() ?? '';
              final phone = data['phone']?.toString() ?? '';
              final memo = data['memo']?.toString() ?? '';

              return Customer(
                number: number,
                name: name,
                phone: phone,
                memo: memo,
                orders: [], // 後で商品データを設定
              );
            } catch (e) {
              print('[loadAllData] ドキュメントパースエラー: $e');
              print('[loadAllData] 問題のドキュメントID: ${doc.id}');
              print('[loadAllData] ドキュメントデータ: ${doc.data()}');
              return null;
            }
          })
          .where((c) => c != null)
          .cast<Customer>()
          .toList();

      // 商品データを読み込み
      final productSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .get();
      final products = productSnapshot.docs
          .map((doc) {
            try {
              final data = doc.data();

              // numberフィールドの型を安全に処理
              int customerNumber;
              if (data['number'] is int) {
                customerNumber = data['number'] as int;
              } else if (data['number'] is String) {
                customerNumber = int.tryParse(data['number'] as String) ?? 0;
              } else {
                customerNumber = 0;
              }

              return {
                'customerNumber': customerNumber,
                'billNo': data['BILL No.']?.toString() ?? '',
                'date': data['date']?.toString() ?? '',
              };
            } catch (e) {
              print('[loadAllData] 商品ドキュメントパースエラー: $e');
              return null;
            }
          })
          .where((p) => p != null)
          .cast<Map<String, dynamic>>()
          .toList();

      // 顧客データに商品データを紐付け
      for (var customer in customers) {
        final customerProducts = products
            .where((p) => p['customerNumber'] == customer.number)
            .map((p) => Order(orderId: p['billNo'], date: p['date']))
            .toList();

        // 日付順でソート（最新を上に）
        customerProducts.sort((a, b) => b.date.compareTo(a.date));

        customer.orders.clear();
        customer.orders.addAll(customerProducts);
      }

      setState(() {
        allCustomers = customers;
        filteredCustomers = List.from(allCustomers);
        _currentPage = 1;
        _expandedCustomerIndex = null;
      });
      print(
        '[loadAllData] ${customers.length}件の顧客データと${products.length}件の商品データを読み込みました',
      );
    } catch (e) {
      print('[loadAllData] エラー: $e');
      setState(() {
        allCustomers = [];
        filteredCustomers = [];
      });
    }
  }

  void _onSearchChanged() {
    String query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        filteredCustomers = List.from(allCustomers);
      } else {
        // 検索結果を取得
        List<Customer> searchResults = allCustomers
            .where(
              (c) =>
                  c.name.contains(query) ||
                  c.phone.contains(query) ||
                  c.number.toString().contains(query),
            )
            .toList();

        // 完全一致を優先してソート
        searchResults.sort((a, b) {
          // 完全一致のスコアを計算
          int scoreA = _calculateMatchScore(a, query);
          int scoreB = _calculateMatchScore(b, query);

          // スコアが高い順（完全一致が上）にソート
          return scoreB.compareTo(scoreA);
        });

        filteredCustomers = searchResults;
      }
      _currentPage = 1;
    });
  }

  // 完全一致スコアを計算する関数
  int _calculateMatchScore(Customer customer, String query) {
    int score = 0;

    // 顧客番号の完全一致（最高スコア）
    if (customer.number.toString() == query) {
      score += 1000;
    }
    // 顧客番号の部分一致
    else if (customer.number.toString().contains(query)) {
      score += 100;
    }

    // 名前の完全一致
    if (customer.name.toLowerCase() == query.toLowerCase()) {
      score += 500;
    }
    // 名前の部分一致
    else if (customer.name.toLowerCase().contains(query.toLowerCase())) {
      score += 50;
    }

    // 電話番号の完全一致
    if (customer.phone == query) {
      score += 300;
    }
    // 電話番号の部分一致
    else if (customer.phone.contains(query)) {
      score += 30;
    }

    return score;
  }

  @override
  Widget build(BuildContext context) {
    int totalPages = (filteredCustomers.length / customersPerPage).ceil();
    int start = (_currentPage - 1) * customersPerPage;
    int end = (_currentPage * customersPerPage).clamp(
      0,
      filteredCustomers.length,
    );
    List<Customer> pageCustomers = filteredCustomers.sublist(start, end);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by customer number, name, or phone',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (_) => _onSearchChanged(),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Customer Number List (${filteredCustomers.length} items)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: pageCustomers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final customer = pageCustomers[idx];
                  final isExpanded = _expandedCustomerIndex == idx;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: isExpanded
                              ? Colors.black.withOpacity(0.35)
                              : Colors.black.withOpacity(0.15),
                          blurRadius: isExpanded ? 18 : 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          tileColor: Colors.white,
                          leading: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              customer.number.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          title: Text(customer.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customer.phone),
                              if (customer.memo.isNotEmpty)
                                Text(
                                  'Memo: ${customer.memo}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                customer.orders.isNotEmpty
                                    ? customer.orders.last.orderId
                                    : 'No Data',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _expandedCustomerIndex = isExpanded ? null : idx;
                            });
                          },
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Order List',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...customer.orders.map(
                                  (order) => ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.only(
                                      left: 0,
                                      right: 0,
                                    ),
                                    title: Text(
                                      order.orderId,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.normal,
                                        fontSize: 16,
                                      ),
                                    ),
                                    trailing: Text(
                                      order.date,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          crossFadeState: isExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  ...List.generate(totalPages, (i) => i + 1)
                      .where(
                        (p) =>
                            (p - _currentPage).abs() <= 2 ||
                            p == 1 ||
                            p == totalPages,
                      )
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p == _currentPage
                                  ? Colors.black87
                                  : Colors.white,
                              foregroundColor: p == _currentPage
                                  ? Colors.white
                                  : Colors.black87,
                              elevation: 4,
                              shadowColor: Colors.black54,
                            ),
                            onPressed: () => setState(() => _currentPage = p),
                            child: Text(p.toString()),
                          ),
                        ),
                      ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < totalPages
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
