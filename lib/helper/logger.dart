class LoggerHelper {
    
    static void info(List<String> prefixes, String message) {

        // Current date and time
        DateTime now = DateTime.now();
        String formattedDate = [
            '${now.year.toString().padLeft(4, '0')}-',
            '${now.month.toString().padLeft(2, '0')}-',
            '${now.day.toString().padLeft(2, '0')} ',
            '${now.hour.toString().padLeft(2, '0')}:',
            '${now.minute.toString().padLeft(2, '0')}:',
            '${now.second.toString().padLeft(2, '0')}',
        ].join('');

        // Print current log info
        print('[${formattedDate}] ${prefixes.map((prefix) => '[${prefix}] ').join('')}${message}');
    }
}