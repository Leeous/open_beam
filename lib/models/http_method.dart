enum HttpMethod {
  get('GET'),
  put('PUT'),
  post('POST'),
  delete('DELETE');

  final String value;

  const HttpMethod(this.value);

  @override
  String toString() => value;
}
