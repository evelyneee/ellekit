
import SwiftUI

struct Tweak: Codable {
    var app: URL
    var tweaks: [URL]
}

struct ContentView: View {
    
    @State
    var tweaks: [Tweak] = []
    
    func addTweak(_ new: Tweak) throws {
        self.tweaks.append(new)
        self.tweaksData = try! JSONEncoder().encode(self.tweaks)
        print(self.tweaksData)
    }
    
    @AppStorage("Tweaks")
    var tweaksData: Data = .init()
    
    @State var addingTweak: Bool = false
    
    @State var newTweak: (app: String, tweaks: [String]) = (app: "", tweaks: [])
    
    var body: some View {
        if addingTweak {
            List {
                HStack {
                    Text("Add tweak")
                        .fontWeight(.semibold)
                    Spacer()
                    Button {
                        self.newTweak.tweaks.append("")
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                TextField("App path", text: self.$newTweak.app)
                ForEach(self.$newTweak.tweaks, id: \.self) { $tweak in
                    TextField("Tweak", text: $tweak)
                }
                Button {
                    let url = NSURL.fileURL(withPath: self.newTweak.app)
                    print(url)
                    let tweakURLs = self.newTweak.tweaks
                        .compactMap(NSURL.fileURL(withPath:))
                    print(tweakURLs)
                    try? addTweak(.init(app: url, tweaks: tweakURLs))
                    self.addingTweak = false
                } label: {
                    Text("Save tweak")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .padding(.top, 5)
            }
        } else {
            List {
                Button("Add tweak") {
                    self.addingTweak.toggle()
                }
                ForEach(tweaks, id: \.app) { tweak in
                    HStack {
                        Text(tweak.app.lastPathComponent)
                        Spacer()
                        Button {
                            
                            print(tweak)
                            let url = tweak.app
                            let path = url.absoluteString.dropFirst(7)
                            let task = Process()
                            task.environment = ["DYLD_INSERT_LIBRARIES":tweak.tweaks.map(\.absoluteString).map { $0.dropFirst(7) }.joined(separator: ":")]
                            task.launchPath = String(path)
                            task.launch()
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onAppear {
                self.tweaks = try! JSONDecoder().decode([Tweak].self, from: self.tweaksData)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
