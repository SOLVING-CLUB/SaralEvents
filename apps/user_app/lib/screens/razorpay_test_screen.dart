import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/payment_test_helper.dart';
import '../core/config/razorpay_config.dart';

/// Test screen for Razorpay integration
/// This should only be used in development/debug mode
class RazorpayTestScreen extends StatefulWidget {
  const RazorpayTestScreen({super.key});

  @override
  State<RazorpayTestScreen> createState() => _RazorpayTestScreenState();
}

class _RazorpayTestScreenState extends State<RazorpayTestScreen> {
  bool _isLoading = false;
  String _testResults = '';
  Map<String, bool> _testResultsMap = {};

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(
          child: Text('Test screen only available in debug mode'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Razorpay Integration Test'),
        backgroundColor: const Color(0xFFFDBB42),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Configuration Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuration',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Key ID: ${RazorpayConfig.keyId}'),
                    Text('App Name: ${RazorpayConfig.appName}'),
                    Text('Currency: ${RazorpayConfig.currency}'),
                    Text('Theme Color: ${RazorpayConfig.themeColor}'),
                    const SizedBox(height: 8),
                    Text(
                      'Status: ${RazorpayConfig.isConfigured ? "✅ Configured" : "❌ Not Configured"}',
                      style: TextStyle(
                        color: RazorpayConfig.isConfigured ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Buttons
            ElevatedButton(
              onPressed: _isLoading ? null : _testConfiguration,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDBB42),
                foregroundColor: Colors.black87,
              ),
              child: const Text('Test Configuration'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testOrderCreation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDBB42),
                foregroundColor: Colors.black87,
              ),
              child: const Text('Test Order Creation'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _runAllTests,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDBB42),
                foregroundColor: Colors.black87,
              ),
              child: const Text('Run All Tests'),
            ),
            
            const SizedBox(height: 16),
            
            // Results
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_testResults.isNotEmpty)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Results',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _testResults,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConfiguration() async {
    setState(() {
      _isLoading = true;
      _testResults = '';
    });

    try {
      final result = PaymentTestHelper.testConfiguration();
      setState(() {
        _testResults = 'Configuration Test: ${result ? "✅ PASSED" : "❌ FAILED"}\n';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResults = 'Configuration Test: ❌ ERROR - $e\n';
        _isLoading = false;
      });
    }
  }

  Future<void> _testOrderCreation() async {
    setState(() {
      _isLoading = true;
      _testResults = '';
    });

    try {
      final result = await PaymentTestHelper.testOrderCreation();
      setState(() {
        _testResults = 'Order Creation Test: ${result ? "✅ PASSED" : "❌ FAILED"}\n';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResults = 'Order Creation Test: ❌ ERROR - $e\n';
        _isLoading = false;
      });
    }
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isLoading = true;
      _testResults = '';
    });

    try {
      final results = await PaymentTestHelper.runAllTests();
      _testResultsMap = results;
      
      String resultsText = 'All Tests Results:\n\n';
      results.forEach((test, result) {
        resultsText += '${result ? "✅" : "❌"} ${test.replaceAll('_', ' ').toUpperCase()}\n';
      });
      
      setState(() {
        _testResults = resultsText;
        _isLoading = false;
      });
      
      // Show dialog with results
      if (mounted) {
        PaymentTestHelper.showTestResults(context, results);
      }
    } catch (e) {
      setState(() {
        _testResults = 'All Tests: ❌ ERROR - $e\n';
        _isLoading = false;
      });
    }
  }
}
