import 'dart:convert' show jsonEncode;
import 'dart:io' show InternetAddress;


class HostFound {

    final String hostname;
    Map<String, InternetAddress> addresses;

    HostFound({
        required this.hostname,
        required this.addresses,
    });

    @override
    Map<String, dynamic> toJson() => {
        'hostname': hostname,
        'addresses': addresses.values
            .map((InternetAddress iaddress) => ({
                'host': iaddress.host,
                'address': iaddress.address,
                'isLinkLocal': iaddress.isLinkLocal,
                'isLoopback': iaddress.isLoopback,
                'isMulticast': iaddress.isMulticast,
                'type': iaddress.type.name,
            }))
            .toList(),
    };

    @override
    String toString() => jsonEncode(toJson());
}