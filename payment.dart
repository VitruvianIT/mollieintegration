import 'package:flutter/material.dart';
import 'package:mollie_flutter/mollie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:uni_links/uni_links.dart';
import 'package:http/http.dart' as http;
import 'dart:async';


class BC extends StatefulWidget {
  final int prijs;
  final String tmpmail;

  BC({
    required this.prijs,
    required this.tmpmail,
  });

  @override
  State<BC> createState() => _BCState();
}

class _BCState extends State<BC> {
  late List<MolliePaymentResponse> payments;
  late StreamSubscription _sub;
  late String streepje;
  late String tmpmail;
  late int prijs;
  late MolliePaymentResponse paymentResponse;
  bool _isLinkHandled = false;

  @override
  void initState() {
    super.initState();
    // the test or live key of Mollies' API
    client.init('...');
    tmpmail = widget.tmpmail;
    prijs = widget.prijs;
    streepje = generateRandomString(6);
    _initUniLinks();
    createOrder();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _initUniLinks() async {
    // Attach a listener to the URI links stream
    _sub = linkStream.listen((String? link) {
      if (link != null) {
        _handleIncomingLink(link);
      }
    }, onError: (err) {
      // Handle error
      print('Error: $err');
    });

    // Check for initial link
    final initialLink = await getInitialLink();
    if (initialLink != null) {
      _handleIncomingLink(initialLink);
    }
  }

  Future<void> _handleIncomingLink(String link) async {
    // Prevent duplicate handling
    if (_isLinkHandled) return;
    _isLinkHandled = true;

    if (link.contains('myproject://payment-return')) {
      // Verify payment status
      try {
        MolliePaymentResponse verifiedPayment = await client.payments.get(paymentResponse.id!);

        if (verifiedPayment.status == 'paid') {
          // Payment successful, call the PHP script
          final response = await http.get(Uri.parse('https://.../app_set_order.php?streepje=$streepje&mail=$tmpmail&prijs=$prijs'));
          if (response.statusCode == 200) {
            // PHP script executed successfully, navigate to thank you page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BackHome()),
            );
          } else {
            // Failed to execute PHP script, handle the error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to execute PHP script')),
            );
          }
        } else {
          // Payment not successful, show an error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment not successful')),
          );
        }
      } catch (e) {
        print('Error verifying payment status: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verifying payment status')),
        );
      }
    }
  }

  Future<void> createOrder() async {
    try {
      MolliePaymentRequest r = MolliePaymentRequest(
        amount: MollieAmount(
          currency: 'EUR',
          value: '$prijs.00',
        ),
        method: 'bancontact',
        redirectUrl: 'myproject://payment-return',
        description: 'SPRES-$streepje',
      );

      paymentResponse = await client.payments.create(r);

      // Open the payment URL in the default browser
      openPaymentURL(paymentResponse.checkoutUrl ?? "");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String generateRandomString(int length) {
    const String chars = "0123456789";
    Random random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
            (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Show a loading indicator
      ),
    );
  }

  void openPaymentURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
