class PatternHelper {

    static RegExp ipaddress = RegExp(r'^\\b(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])\\.)(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\\.){2}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\\b$');
    static RegExp hostname = RegExp(r'^[a-zA-Z0-9]+[a-zA-Z0-9\\.\\-_]{1,253}$');
    static RegExp nsschema = RegExp(
        r'^(?:(udp|tcp|https):\/\/)' // protocol
        r'([a-zA-Z0-9.-]+)'          // hostname or IP
        r':(\d{1,5})'                // Port
        r'(\/[a-zA-Z0-9\-._~\/]*)?$' // Optional path (without # or ?)
    );

    // static bool Function(String?) validate = (String? text) => ((text != null) && (HostnameValidation.pattern.firstMatch(text) != null));

    static bool validate(RegExp pattern, String value) {
        if(value == null)
            return false;
        return !!pattern.hasMatch(value);
    }
}