import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

const version = '0.1';

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.first == 'help' || arguments.first == '?') {
    type();
  } else if (arguments.first == 'version') {
    print('Dart CLI version $version');
  } else if (arguments.first == 'wikipedia') {
    final inputArgs = arguments.length > 1 ? arguments.sublist(1) : null;
    searchWikipedia(inputArgs);
  } else {
    type();
  }
}

void searchWikipedia(List<String>? arguments) async {
  final String articleTitle;

  if (arguments == null || arguments.isEmpty) {
    print('아티클 제목을 먼저 입력하세요.');
    
    final inputFromStdin = stdin.readLineSync();
    if (inputFromStdin == null || inputFromStdin.isEmpty) {
      print('아티클 제목이 없습니다. 종료합니다.');
      return;
    }
    articleTitle = inputFromStdin;
  } else {
    articleTitle = arguments.join(' ');
  }
  print('"$articleTitle"를 찾아보는중입니다 . 잠시만 기다려주세요.');
  
  var articleContent = await getWikipediaArticle(articleTitle);
  print(articleContent);
}

void type() {
  print("사용 가능한 명령어: 'help', 'version', 'search (아티클 제목)");
}

Future<String> getWikipediaArticle(String articleTitle) async {
  final url = Uri.https(
    'en.wikipedia.org',
    '/api/rest_v1/page/summary/$articleTitle',
  );
  final response = await http.get(url);

  if (response.statusCode == 200) {
    return response.body;
  }

  else if (response.statusCode == 404) {
    return '"$articleTitle" 아티클을 찾을 수 없습니다.';
  }

  return 'Error:"$articleTitle"을/를 "${response.statusCode}" 로 인하여 검색을 중지했습니다';
}

/* https://dart.dev/learn/tutorial/packages-libs
  여기부터 해야함!!
*/