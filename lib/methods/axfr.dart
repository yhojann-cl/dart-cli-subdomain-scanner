import 'package:dnslib/dnslib.dart' show
    DNSClient, DNSServer, DNSResponseRecord, DNSRecordTypes;


enum AXFREvent {
    starting,
    response,
    found,
    finalized,
    error,
}

class AXFRMethod {

    static Future<void> find({
        required String hostname,
        required DNSServer dnsServer,
        required void Function(AXFREvent, [ dynamic ]) onEvent,
    }) async {

        // Call user event
        onEvent(AXFREvent.starting);

        try {

            // Create query
            List<DNSResponseRecord> records = await DNSClient.query(
                domain: hostname,
                dnsRecordType: DNSRecordTypes.findByName('AXFR'),
                dnsServer: dnsServer);

            // Call user event
            onEvent(AXFREvent.response, records.length);

            // Process each record
            for (DNSResponseRecord record in records) {

                // Call user event
                onEvent(AXFREvent.found, record.name.toLowerCase().trim());

                // TODO: Find subdomains in texts of values
            }

            // Call user event
            onEvent(AXFREvent.finalized);

        } catch(e) {

            // Call user event
            onEvent(AXFREvent.error, e);
        }
    }
}