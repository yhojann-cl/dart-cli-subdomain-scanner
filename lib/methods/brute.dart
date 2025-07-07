import 'dart:io' show Duration, sleep;
import 'dart:async' show Timer;
import 'dart:collection' show Queue;
import 'dart:math' show pow;
import 'package:dnslib/dnslib.dart' show DNSClient, DNSServer, DNSResponseRecord, DNSRecordTypes;
import 'package:dictlib/dictlib.dart' show DictLib;


enum BruteEvent {
    starting,
    creatingTasks,
    validating,
    retry,
    found,
    finalized,
    error,
}


class _LastValidation {

    final int id;
    final String hostname;
    final int wordId;
    final int totalWords;

    _LastValidation({
        required this.id,
        required this.hostname,
        required this.wordId,
        required this.totalWords,
    });
}


class BruteMethod {

    static Future<void> find({
        required String hostname,
        required int maxLength,
        required DNSServer dnsServer,
        required void Function(BruteEvent, [ dynamic ]) onEvent,
    }) async {

        // Call user event
        onEvent(BruteEvent.starting);

        final int ntasks = 4;
        final int maxRetries = 15;
        int totalWords = 0;
        int currentWordId = 0;
        final String characters = 'abcdefghijklmnopqrstuvwxyz0123456789_';

        // Create the dictionary
        final dict = DictLib(length: maxLength, characters: characters);

        // Create queue producer-consumer
        final queue = Queue<String>()..addAll(dict);

        // Declare first last log for monitoring
        _LastValidation? lastValidation = null;

        // Words calculation
        for (int i = 1; i <= maxLength; i++) {
            totalWords += pow(characters.length, i).toInt();
        }

        Future<void> task(int id) async {

            // Process subdomains until none remain
            while(queue.isNotEmpty) {

                // Get next word
                final String word = queue.removeFirst();
                currentWordId++;
                final int wordId = currentWordId;
                int retryId = 1;

                // Process the same task until retries are exhausted
                while(true) {
                    
                    try {

                        lastValidation = _LastValidation(
                            id: id,
                            hostname: '$word.$hostname',
                            wordId: wordId,
                            totalWords: totalWords,
                        );

                        // Create query
                        List<DNSResponseRecord> records = await DNSClient.query(
                            domain: '$word.$hostname',
                            dnsRecordType: DNSRecordTypes.findByName('A'),
                            dnsServer: dnsServer);

                        if(records.length > 0) {

                            // Call user event
                            onEvent(BruteEvent.found, {
                                'id': id,
                                'hostname': '$word.$hostname',
                                'wordId': wordId,
                                'totalWords': totalWords,
                            });
                        }

                        for (DNSResponseRecord record in records) {

                            // Call user event
                            onEvent(BruteEvent.found, {
                                'id': id,
                                'hostname': record.name,
                                'wordId': wordId,
                                'totalWords': totalWords,
                            });

                            // TODO: Find subdomains in texts of values
                        }
                        
                        // End retries while
                        break;

                    } catch(e) {
                        
                        // Call user event
                        onEvent(BruteEvent.error, e);
                    }

                    // Retry again
                    retryId++;

                    if(retryId > maxRetries) {

                        // Call user event
                        onEvent(BruteEvent.error, 'Unable to resolve $word.$hostname. Maximum retries exhausted.');

                        break;
                    }

                    // Call user event
                    onEvent(BruteEvent.retry, {
                        'id': id,
                        'hostname': '$word.$hostname',
                        'wordId': wordId,
                        'totalWords': totalWords,
                    });

                    // Await 1 second
                    sleep(const Duration(seconds: 1));
                }
            }
        }

        
        // Call user event
        onEvent(BruteEvent.creatingTasks);

        // Create tasks
        final tasks = List.generate(ntasks, (i) => task(i));

        // Call user event
        if(lastValidation != null) {
            onEvent(BruteEvent.validating, {
                'id': lastValidation!.id,
                'hostname': lastValidation!.hostname,
                'wordId': lastValidation!.wordId,
                'totalWords': lastValidation!.totalWords,
            });
        }
        
        final Timer loggerTimer = Timer.periodic(Duration(seconds: 5), (Timer t) {

            // Call user event
            if(lastValidation != null) {
                onEvent(BruteEvent.validating, {
                    'id': lastValidation!.id,
                    'hostname': lastValidation!.hostname,
                    'wordId': lastValidation!.wordId,
                    'totalWords': lastValidation!.totalWords,
                });
            }
        });

        // Await all tasks
        await Future.wait(tasks);

        // Finalize logger monitor
        loggerTimer.cancel();

        // Call user event
        onEvent(BruteEvent.finalized);
    }
}