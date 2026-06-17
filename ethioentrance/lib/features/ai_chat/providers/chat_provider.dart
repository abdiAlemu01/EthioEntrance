
// AI chat provider.

import 'package:firebase_ai/firebase_ai.dart';


final FirebaseAI _firebaseAI = FirebaseAI.googleAI();

Future<String> askAI(String prompt) async {
  final model = _firebaseAI.generativeModel(
    model: 'gemini-2.5-flash-lite',
  );

  final response = await model.generateContent([Content.text(prompt)]);

  return response.text ?? "No response";
}