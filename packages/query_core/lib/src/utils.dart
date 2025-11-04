import 'dart:convert';

// Custom encoder for enums
dynamic customEncode(dynamic item) {
  return item.toString();
}

String queryKeyToCacheKey(List<Object> queryKey) {
  // Encode the queryKey to JSON using the custom encoder
  String json = jsonEncode(queryKey, toEncodable: customEncode);

  // Decode the JSON back to a List<dynamic>
  List<dynamic> decodedList = jsonDecode(json);

  var input = decodedList.join(';');

  // Regular expression to match properties with null values
  RegExp nullPropertyPattern = RegExp(r'\w+: null,?\s*');

  // Join the resulting entries with a semicolon
  return input.replaceAll(nullPropertyPattern, '');
}
