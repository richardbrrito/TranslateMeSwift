//
//  ContentView.swift
//  FireChat
//
//  Created by Richard Brito on 11/4/25.
//

import SwiftUI
import FirebaseFirestore

struct ContentView: View {
    @State private var userInput: String = ""
    @State private var translatedText: String = ""
    @State private var isLoading = false
    @State private var translations: [Translation] = []
    
    private let db = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Translate Me!")
                .font(.headline)
            
            TextField("Enter your word", text: $userInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    await translateText()
                }
            }) {
                Text("Translate")
            }
            
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled( userInput.isEmpty)
            
            if !translatedText.isEmpty {
                Text("Translation: \(translatedText)")
                    .padding()
                    .multilineTextAlignment(.center)
            }
            
            Divider()
                .padding(.vertical, 10)
            
            // check if translations list is empty
            if translations.isEmpty {
                Text("No saved translations yet.")
                    .foregroundColor(.gray)
            } else {
                List(translations.sorted(by: { $0.timestamp > $1.timestamp })) { translation in
                    VStack(alignment: .leading) {
                        Text(translation.originalText)
                            .font(.headline)
                        Text(translation.translatedText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(translation.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxHeight: 300)
            }
            
            Button(role: .destructive, action: {
                Task { await clearTranslations() }
            }) {
                Text("Clear All Translations")
                    .padding()
                    .background(Color.red.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.bottom)
        }
        .padding()
        .onAppear {
            listenForTranslations()
        }
    }
    
    // MARK: - Translation Struct
    struct Translation: Identifiable {
        let id: String
        let originalText: String
        let translatedText: String
        let timestamp: Date
    }
    
    // MARK: - Translate and Save
    @MainActor
    func translateText() async {
        guard let encodedText = userInput.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let urlString = "https://api.mymemory.translated.net/get?q=\(encodedText)&langpair=en|es"
        guard let url = URL(string: urlString) else { return }
        
        isLoading = true
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let responseData = json["responseData"] as? [String: Any],
                let translated = responseData["translatedText"] as? String
            else {
                translatedText = "Translation failed."
                isLoading = false
                return
            }
            
            translatedText = translated
            
            // save to firestore
            let translationData: [String: Any] = [
                "originalText": userInput,
                "translatedText": translated,
                "timestamp": Timestamp(date: Date())
            ]
            
            try await db.collection("translations").addDocument(data: translationData)
            
            userInput = ""
            isLoading = false
            
        } catch {
            translatedText = "Error: \(error.localizedDescription)"
            isLoading = false
        }
    }

    
    // MARK: - Real-time Listener
    func listenForTranslations() {
        db.collection("translations").addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            self.translations = documents.compactMap { doc in
                let data = doc.data()
                guard let original = data["originalText"] as? String,
                      let translated = data["translatedText"] as? String,
                      let timestamp = data["timestamp"] as? Timestamp else { return nil }
                return Translation(id: doc.documentID,
                                   originalText: original,
                                   translatedText: translated,
                                   timestamp: timestamp.dateValue())
            }
        }
    }
    
    // MARK: - Clear All
    func clearTranslations() async {
        do {
            let snapshot = try await db.collection("translations").getDocuments()
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
            translations.removeAll()
        } catch {
            print("Error deleting translations: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
