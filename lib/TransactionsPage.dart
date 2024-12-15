import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

final pb = PocketBase('https://congress-stood.pockethost.io/');

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({Key? key}) : super(key: key);

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  List<Map<String, dynamic>> transactions = [];
  String selectedType = 'All';
  String selectedStatus = 'All';
  String searchQuery = '';
  DateTimeRange? dateRange;

  @override
  void initState() {
    super.initState();
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    try {
      final result = await pb.collection('sales').getFullList(
        expand: 'status',
      );

      setState(() {
        transactions = result.map((record) {
          final data = record.data;

          String status = 'Paid';
          if (record.expand != null &&
              record.expand.containsKey('status') &&
              record.expand['status'] is Map<String, dynamic>) {
            final statusData = record.expand['status'] as Map<String, dynamic>;
            status = statusData['status'] ?? 'Paid';
          }

          final created = data['created'] ?? DateTime.now().toIso8601String();

          return {
            ...data,
            'status': status,
            'created': created,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    }
  }

  List<Map<String, dynamic>> applyFilters() {
    List<Map<String, dynamic>> filteredTransactions = List.from(transactions);

    if (selectedType != 'All') {
      filteredTransactions = filteredTransactions
          .where((transaction) => transaction['unit_type'] == selectedType)
          .toList();
    }

    if (selectedStatus != 'All') {
      filteredTransactions = filteredTransactions
          .where((transaction) => transaction['status'] == selectedStatus)
          .toList();
    }

    if (searchQuery.isNotEmpty) {
      filteredTransactions = filteredTransactions
          .where((transaction) =>
              transaction['receipt_number']?.toString().contains(searchQuery) ??
              false)
          .toList();
    }

    if (dateRange != null) {
      // Extract start and end of the selected date range
      final startOfDay = DateTime(dateRange!.start.year, dateRange!.start.month, dateRange!.start.day);
      final endOfDay = DateTime(dateRange!.end.year, dateRange!.end.month, dateRange!.end.day, 23, 59, 59);

      filteredTransactions = filteredTransactions.where((transaction) {
        final createdDate = transaction['created'];
        if (createdDate == null || createdDate == 'null') return false;

        try {
          // Parse the `created` date using DateTime.parse()
          final transactionDate = DateTime.parse(createdDate);

          // Compare with the adjusted date range
          return transactionDate.isAfter(startOfDay) && transactionDate.isBefore(endOfDay);
        } catch (e) {
          debugPrint('Error parsing transaction date: $e');
          return false;
        }
      }).toList();

    }

    return filteredTransactions;
  }

  Future<void> exportToCSV(List<Map<String, dynamic>> filteredData) async {
    try {
      // Create CSV headers
      final headers = [
        'Date & Time',
        'Receipt Number',
        'Player Name',
        'Unit Type',
        'Status',
        'Amount'
      ];

      // Convert transactions into rows
      final rows = [
        headers,
        ...filteredData.map((transaction) {
          final created = transaction['created'] != null
              ? DateFormat('yyyy-MM-dd HH:mm')
                  .format(DateTime.parse(transaction['created']))
              : 'Unknown Date';
          return [
            created,
            transaction['receipt_number'] ?? 'No Receipt',
            transaction['player_name'] ?? 'Unknown Player',
            transaction['unit_type'] ?? 'Unknown Type',
            transaction['status'] ?? 'Unknown Status',
            transaction['amount_due'] ?? '0.00',
          ];
        }).toList(),
      ];

      // Convert rows to CSV format
      final csvData = const ListToCsvConverter().convert(rows);

      // Get the device's Documents directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/transactions.csv';

      // Write CSV data to the file
      final file = File(filePath);
      await file.writeAsString(csvData);

      // Notify the user
      debugPrint('CSV file saved to $filePath');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('CSV file exported to: $filePath'),
      ));
    } catch (e) {
      debugPrint('Error exporting to CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error exporting to CSV: $e'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = applyFilters();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Transaction History',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilters(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Export filtered data to CSV
                exportToCSV(filteredTransactions);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Export to CSV',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _buildResponsiveTransactionsTable(filteredTransactions),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    dateRange = picked;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.black54),
                    const SizedBox(width: 10),
                    Text(
                      dateRange == null
                          ? 'Select Date Range'
                          : '${DateFormat('yyyy-MM-dd').format(dateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(dateRange!.end)}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: selectedType,
              onChanged: (value) {
                setState(() {
                  selectedType = value!;
                });
              },
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Types')),
                DropdownMenuItem(value: 'PS5', child: Text('PS5')),
                DropdownMenuItem(value: 'Pool Table', child: Text('Pool Table')),
              ],
              underline: Container(),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: selectedStatus,
              onChanged: (value) {
                setState(() {
                  selectedStatus = value!;
                });
              },
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Status')),
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'Paid', child: Text('Paid')),
              ],
              underline: Container(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  hintText: 'Search Receipt Number',
                  hintStyle: const TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResponsiveTransactionsTable(List<Map<String, dynamic>> transactions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: constraints.maxWidth > 600 ? 50.0 : 20.0,
                horizontalMargin: 16.0,
                headingRowHeight: 60.0,
                headingRowColor: MaterialStateColor.resolveWith(
                  (states) => Colors.teal.shade50,
                ),
                columns: const [
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Date & Time',
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Receipt Number',
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Player Name',
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Type',
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Status',
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Amount',
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
                rows: transactions.map((transaction) {
                  final created = transaction['created'];
                  final date = created != null
                      ? DateFormat('yyyy-MM-dd HH:mm')
                          .format(DateTime.parse(created))
                      : 'Unknown Date';

                  final receiptNumber =
                      transaction['receipt_number'] ?? 'No Receipt';
                  final playerName =
                      transaction['player_name'] ?? 'Unknown Player';
                  final unitType = transaction['unit_type'] ?? 'Unknown Type';
                  final status = transaction['status'] ?? 'Unknown Status';
                  final amountDue = transaction['amount_due'] ?? '0.00';

                  return DataRow(cells: [
                    DataCell(Text(date)),
                    DataCell(Text(receiptNumber)),
                    DataCell(Text(playerName)),
                    DataCell(Text(unitType)),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: status == 'Paid'
                            ? Colors.green.withOpacity(0.2)
                            : Colors.yellow.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: status == 'Paid' ? Colors.green : Colors.yellow,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )),
                    DataCell(Text('\$${amountDue.toString()}')),
                  ]);
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
