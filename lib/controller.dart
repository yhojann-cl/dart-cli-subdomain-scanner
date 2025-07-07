import 'dart:io' show InternetAddress, Platform, File, DateTime, Directory;
import 'dart:math' show Random;
import 'dart:convert' show JsonEncoder;
import 'package:intl/intl.dart' show NumberFormat;
import 'package:args/args.dart' show ArgParser, ArgResults;
import 'package:dnslib/dnslib.dart' show DNSServer, DNSProtocol;
import 'domain/host_found.dart' show HostFound;
import 'helper/pattern.dart' show PatternHelper;
import 'helper/logger.dart' show LoggerHelper;
import 'methods/axfr.dart' show AXFRMethod, AXFREvent;
import 'methods/brute.dart' show BruteMethod, BruteEvent;
import 'filters/address.dart' show AddressFilter, AddressEvent;


/// Main controller class.
class Controller {

    Map<String, HostFound> results = { };
    DateTime startExecution = DateTime.now();

    /// Controller constructor.
    Controller(List<String> arguments) {
        this.run(arguments);
    }

    Future<void> run(List<String> arguments) async {

        this.startExecution = DateTime.now();

        // Arguments parser
        ArgParser parser = ArgParser();
        
        parser.addFlag('help',
            abbr: 'h',
            negatable: false,
            help: 'Show this help message.');

        parser.addOption('ns',
            mandatory: false,
            help: [
                'Use a custom name server with uri schema format:',
                '  [protocol]://[address or hostname]:port/path',
                'Supported protocols: udp, tcp, doh.',
                'Set path option only for DoH servers.',
                'Examples:',
                '  doh://google.dns:443/dns-query',
                '  udp://192.168.1.1:53',
                '  tcp://192.168.1.1:53',
            ].join(Platform.lineTerminator),
            defaultsTo: 'tcp://8.8.8.8:53');

        parser.addOption(
            'out',
            abbr: 'o',
            help: [
                'Save the progress on a json file. By default it generates',
                'a random temporary file.'
            ].join(Platform.lineTerminator),
            defaultsTo: await _createTempFile(extension: 'json'));

        parser.addOption('brute',
            help: '[method] Find using brute-force mode using n characters.',
            mandatory: false);

        parser.addFlag('axfr',
            help: '[method] Find using a DNS zone transfer query.',
            negatable: false,
            defaultsTo: false);

        parser.addFlag('address',
            help: '[filter] Resolve the IP address for each subdomain.',
            negatable: false,
            defaultsTo: false);

        // TODO: Create default strategy: use all.

        try {
            // Parse arguments
            final ArgResults argv = parser.parse(arguments);

            // Choose default nameserver
            DNSServer dnsServer = this.getDNSServerFromNSString(argv['ns']);

            // Protocol correction for AXFR
            if(argv['axfr'] && (dnsServer.protocol == DNSProtocol.udp)) {
                dnsServer.protocol = DNSProtocol.tcp;
            }
            
            if (argv.rest.isEmpty) {
                throw ArgumentError();
            }

            final String hostname = argv.rest[0];

            if(argv.wasParsed('brute')) {
                await BruteMethod.find(
                    hostname: hostname,
                    maxLength: int.parse(argv['brute']),
                    dnsServer: dnsServer,
                    onEvent: (BruteEvent event, [ dynamic obj ]) {

                        if(event == BruteEvent.starting) {
                            LoggerHelper.info([ 'brute' ], 'Finding subdomains using bruteforce ...');

                        } else if(event == BruteEvent.creatingTasks) {    
                            LoggerHelper.info([ 'brute' ], 'Creating async tasks ...');

                        } else if(event == BruteEvent.validating) {

                            // Parse input event
                            final Map<String, dynamic> data = obj!;

                            LoggerHelper.info([
                                'brute',
                                'task-${data['id']}',
                                'eta-${NumberFormat('#,###').format(data['wordId'])}/${NumberFormat('#,###').format(data['totalWords'])}'
                            ], 'Finding for ${data['hostname']} ...');

                        } else if(event == BruteEvent.retry) {

                            // Parse input event
                            final Map<String, dynamic> data = obj!;

                            LoggerHelper.info([
                                'brute',
                                'task-${data['id']}',
                                'eta-${NumberFormat('#,###').format(data['wordId'])}/${NumberFormat('#,###').format(data['totalWords'])}'
                            ], 'Retrying ...');

                        } else if(event == BruteEvent.found) {

                            // Parse input event
                            final Map<String, dynamic> data = obj!;

                            // Is already saved?
                            if(this.results.containsKey(data['hostname']))
                                return;

                            LoggerHelper.info([
                                'brute',
                                'task-${data['id']}',
                                'eta-${NumberFormat('#,###').format(data['wordId'])}/${NumberFormat('#,###').format(data['totalWords'])}',
                                'found',
                            ], data['hostname']);

                            // Add result to stack
                            this.results[data['hostname']] = HostFound(
                                hostname: data['hostname'],
                                addresses: { },
                            );

                            // Save progress
                            this.saveResults(argv['out']);
                            
                        } else if(event == BruteEvent.finalized) {
                            LoggerHelper.info([ 'brute' ], 'Finalized.');

                        } else if(event == BruteEvent.error) {
                            LoggerHelper.info([ 'brute', 'error' ], '$obj');
                        }
                    },
                );
            }

            if(argv['axfr']) {
                await AXFRMethod.find(
                    hostname: hostname,
                    dnsServer: dnsServer,
                    onEvent: (AXFREvent event, [ dynamic obj ]) {

                        if(event == AXFREvent.starting) {
                            LoggerHelper.info([ 'axfr' ], 'Sending query to server ...');
                            
                        } else if(event == AXFREvent.response) {
                            LoggerHelper.info([ 'axfr' ], '$obj records found.');

                        } else if(event == AXFREvent.found) {

                            // Parse input event
                            final String hostname = obj!;

                            // Is already saved?
                            if(this.results.containsKey(hostname))
                                return;

                            LoggerHelper.info([ 'axfr', 'found' ], '$obj');

                            // Add result to stack
                            this.results[hostname] = HostFound(
                                hostname: hostname,
                                addresses: { },
                            );

                            // Save progress
                            this.saveResults(argv['out']);
                            
                        } else if(event == AXFREvent.finalized) {
                            LoggerHelper.info([ 'axfr' ], 'Finalized.');

                        } else if(event == AXFREvent.error) {
                            LoggerHelper.info([ 'axfr', 'error' ], '$obj');
                        }
                    },
                );
            }

            if(argv['address']) {
                await AddressFilter.apply(
                    results: this.results,
                    dnsServer: dnsServer,
                    onEvent: (AddressEvent event, [ dynamic obj ]) {

                        if(event == AddressEvent.starting) {
                            LoggerHelper.info([ 'address' ], 'Resolving ip address for each hostname ...');

                        } else if(event == AddressEvent.validating) {

                            // Parse input event
                            final Map<String, dynamic> data = obj!;

                            // Progress log
                            LoggerHelper.info([
                                'address',
                                'eta-${NumberFormat('#,###').format(data['id'])}/${NumberFormat('#,###').format(data['total'])}',
                            ], 'Find addressess for ${data['hostname']} ...');

                        } else if(event == AddressEvent.found) {

                            // Parse input event
                            final Map<String, dynamic> data = obj!;
                            
                            // Is already saved?
                            if(this.results.containsKey(data['hostname']) &&
                                this.results[data['hostname']]!.addresses.containsKey(data['iaddress']!.address))
                                return;

                            // Progress log
                            LoggerHelper.info([
                                'address',
                                'eta-${NumberFormat('#,###').format(data['id'])}/${NumberFormat('#,###').format(data['total'])}',
                                'found',
                            ], '${data['hostname']} is ${data['iaddress']!.address}');

                            // Add value to stack
                            this.results[data['hostname']]!.addresses[data['iaddress']!.address] = data['iaddress']!;

                            // Save progress
                            this.saveResults(argv['out']);

                        } else if(event == AddressEvent.finalized) {
                            LoggerHelper.info([ 'address' ], 'Finalized.');

                        } else if(event == AddressEvent.error) {
                            LoggerHelper.info([ 'address', 'error' ], '$obj');
                        }
                    }
                );
            }

            // TODO: Find aliases CNAME

            // Save progress
            this.saveResults(argv['out']);

            // Progress log
            LoggerHelper.info([ ], 'Finalized.');

            // Final report
            this.finalReport(argv['out']);

        } on ArgumentError catch (e) {
            LoggerHelper.info([ 'error' ], e.toString());
            this.help(parser);

        } on FormatException catch (e) {
            LoggerHelper.info([ 'error' ], e.toString());
            this.help(parser);
        }
    }

    void finalReport(String projectPath) {
        
        // Elapsed time
        final DateTime stopExecution = DateTime.now();
       
        print([
            '',
            '--------------------------------------------------------------//',
            'Total hosts found   : ${this.results.keys.length}',
            'Total address found : ${this.results.values.expand((host) => host.addresses.values.map((ip) => ip.address)).toSet().length}',
            'Project path        : ${File(projectPath).absolute.path}',
            'Start date          : ${this.startExecution.toIso8601String()}',
            'End date            : ${stopExecution.toIso8601String()}',
            'Elapsed time        : ${stopExecution.difference(this.startExecution).toString()}',
            '',
        ].join(Platform.lineTerminator));
    }

    void help(ArgParser parser) {
        print([
            '',
            'WHK Subdomains Scanner.',
            'Usage: wss [options] [methods] [filters] <hostname>',
            '',
            parser.usage,
            '',
            'Examples:',
            '  wss --ns doh://google.dns:443/dns-query --brute 4 example.com',
            '  wss --ns udp://192.168.1.1:53 --brute 2 example.com',
            '  wss --ns tcp://8.8.8.8:53 --brute 4 --address --out project.json google.com',
            '  wss --ns tcp://nsztm1.digi.ninja:53 --axfr zonetransfer.me',
            '  wss --ns tcp://nsztm1.digi.ninja:53 --axfr --brute 4 zonetransfer.me',
            '',
        ].join(Platform.lineTerminator));
    }

    Future<void> saveResults(String path) async {
        final String jsonString = JsonEncoder.withIndent('    ').convert(results);
        final File file = File(path);
        await file.writeAsString(jsonString);
    }

    DNSServer getDNSServerFromNSString(String ns) {
        
        final RegExpMatch? match = PatternHelper.nsschema.firstMatch(ns);

        if(match == null)
            throw ArgumentError('Unknown NS source uri schema. See help using --help option.');

        final DNSProtocol protocol = DNSProtocol.values.firstWhere((element) => element.name == match!.group(1)!);
        final String host = match!.group(2)!;
        final int port = int.parse(match!.group(3)!);
        final String path = match!.group(4) ?? '/';

        return DNSServer(
            host: host,
            port: port,
            protocol: protocol,
            path: path,
        );
    }

    /// Creates a single temporary file with a random name and optional extension.
    Future<String> _createTempFile({ String prefix = 'tmp_', String? extension }) async {
        final tempDir = Directory.systemTemp;
        final random = Random.secure();
        final timestamp = DateTime.now().microsecondsSinceEpoch;

        while (true) {
            final randomPart = List.generate(6, (_) => random.nextInt(36).toRadixString(36)).join();
            final filename = '$prefix$timestamp\_$randomPart${extension != null ? '.$extension' : ''}';

            final file = File('${tempDir.path}/$filename');

            if (!await file.exists()) {
                await file.create();
                return file.path;
            }
        }
    }
}