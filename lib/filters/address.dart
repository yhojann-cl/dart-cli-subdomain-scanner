import 'dart:io' show InternetAddress;
import 'package:dnslib/dnslib.dart' show DNSServer;
import '../domain/host_found.dart' show HostFound;


enum AddressEvent {
    starting,
    validating,
    found,
    finalized,
    error,
}


class AddressFilter {

    static Future<void> apply({
        required Map<String, HostFound> results,
        required DNSServer dnsServer,
        required void Function(AddressEvent, [ dynamic ]) onEvent,
    }) async {
        
        // Call user event
        onEvent(AddressEvent.starting);

        try{
        
            // Progress
            int i = 0;

            for (HostFound hostFound in results.values) {

                // Increase item id
                i++;

                // Call user event
                onEvent(AddressEvent.validating, {
                    'id': i,
                    'total': results.keys.length,
                    'hostname': hostFound.hostname,
                });

                // List of the adresses
                List<InternetAddress> addresses = [ ];
                try{
                    // Find adresses
                    // TODO: Replace for dns query and custom ns server
                    addresses = await InternetAddress.lookup(hostFound.hostname);
                } catch(e) {
                    // Unreachable hostname
                }

                for(InternetAddress iaddress in addresses) {
                    
                    // Call user event
                    onEvent(AddressEvent.found, {
                        'id': i,
                        'total': results.keys.length,
                        'hostname': hostFound.hostname,
                        'iaddress': iaddress,
                    });
                }
            }

        } catch(e) {

            // Call user event
            onEvent(AddressEvent.error, e);
        }

        // Call user event
        onEvent(AddressEvent.finalized);
    }
}