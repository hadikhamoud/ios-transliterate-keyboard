import UIKit

class KeyboardViewController: UIInputViewController {

    var suggestionBar: UISegmentedControl!
    var suggestionContainer: UIView!
    var currentWord = ""
    var timer: Timer?
    var stackViews: [UIStackView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        addSuggestionContainer()
        addKeyboardButtons()
    }

    func addSuggestionContainer() {
        suggestionContainer = UIView()
        suggestionContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(suggestionContainer)

        suggestionBar = UISegmentedControl(items: ["Suggestion 1", "Suggestion 2", "Suggestion 3"])
        suggestionBar.addTarget(self, action: #selector(suggestionTapped(_:)), for: .valueChanged)
        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        suggestionContainer.addSubview(suggestionBar)

        NSLayoutConstraint.activate([
            suggestionContainer.topAnchor.constraint(equalTo: view.topAnchor),
            suggestionContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionContainer.heightAnchor.constraint(equalToConstant: 50)
        ])

        NSLayoutConstraint.activate([
            suggestionBar.topAnchor.constraint(equalTo: suggestionContainer.topAnchor),
            suggestionBar.leadingAnchor.constraint(equalTo: suggestionContainer.leadingAnchor),
            suggestionBar.trailingAnchor.constraint(equalTo: suggestionContainer.trailingAnchor),
            suggestionBar.bottomAnchor.constraint(equalTo: suggestionContainer.bottomAnchor)
        ])
    }

    func addKeyboardButtons() {
        let keys = [
            ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
            ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
            ["z", "x", "c", "v", "b", "n", "m"],
            ["space", "delete"]
        ]

        let buttonWidth: CGFloat = 35
        let buttonHeight: CGFloat = 45
        let buttonSpacing: CGFloat = 8

        for (rowIndex, row) in keys.enumerated() {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .equalSpacing
            stackView.alignment = .center
            stackView.spacing = buttonSpacing

            for key in row {
                let button = KeyboardButton(type: .system)
                button.setTitle(key, for: .normal)
//                button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
//                button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
                button.addTarget(self, action: #selector(keyPressed(_:)), for: .touchUpInside)
                stackView.addArrangedSubview(button)
            }

            stackView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stackView)
            stackViews.append(stackView)
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: suggestionContainer.bottomAnchor, constant: CGFloat(rowIndex) * (buttonHeight + buttonSpacing)),
                stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: buttonSpacing),
                stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -buttonSpacing)
            ])
        }
    }

    @objc func keyPressed(_ sender: UIButton) {
        guard let key = sender.titleLabel?.text else { return }
        
        if key == "space" {
            textDocumentProxy.insertText(" ")
            currentWord = ""
//            suggestionBar.isHidden = true
        } else if key == "delete" {
            textDocumentProxy.deleteBackward()
            if !currentWord.isEmpty {
                currentWord.removeLast()
            }
        } else {
            textDocumentProxy.insertText(key)
            currentWord.append(key)
            scheduleTransliteration()
        }
    }

    func scheduleTransliteration() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(requestTransliteration), userInfo: nil, repeats: false)
    }

    @objc func requestTransliteration() {
        transliterate(word: currentWord)
    }

    @objc func suggestionTapped(_ sender: UISegmentedControl) {
        let selectedSuggestion = sender.titleForSegment(at: sender.selectedSegmentIndex)
        replaceCurrentWord(with: selectedSuggestion ?? "")
    }

    func replaceCurrentWord(with word: String) {
        for _ in 0..<currentWord.count {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(word)
        currentWord = ""
        suggestionBar.isHidden = true
    }

    func transliterate(word: String) {
        queryYamliAPI(query: word) { suggestions in
            DispatchQueue.main.async {
                self.updateSuggestionBar(with: suggestions)
            }
        }
    }

    func updateSuggestionBar(with suggestions: [String]) {
        for (index, suggestion) in suggestions.prefix(3).enumerated() {
            suggestionBar.setTitle(suggestion, forSegmentAt: index)
        }
        suggestionBar.isHidden = suggestions.isEmpty
    }
}

// Your queryYamliAPI function
func queryYamliAPI(query: String, completion: @escaping ([String]) -> Void) {
    let urlString = "https://api.yamli.com/transliterate.ashx"
    guard var urlComponents = URLComponents(string: urlString) else {
        completion([])
        return
    }

    urlComponents.queryItems = [
        URLQueryItem(name: "word", value: query),
        URLQueryItem(name: "tool", value: "api"),
        URLQueryItem(name: "account_id", value: "000006"),
        URLQueryItem(name: "prot", value: "https"),
        URLQueryItem(name: "hostname", value: "AliMZaini"),
        URLQueryItem(name: "path", value: "yamli-api"),
        URLQueryItem(name: "build", value: "5515")
    ]

    guard let url = urlComponents.url else {
        completion([])
        return
    }

    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data, error == nil else {
            completion([])
            return
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let resultsString = json["r"] as? String {
                let results = resultsString.split(separator: "|").map { String($0.split(separator: "/")[0]) }
                let topResults = Array(results.prefix(3))
                completion(topResults)
            } else {
                completion([])
            }
        } catch {
            completion([])
        }
    }

    task.resume()
}
